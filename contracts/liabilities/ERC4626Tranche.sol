// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author The Chairman (https://github.com/TChairman/ERC4626Suite)

import "../equity/ERC4626Coupon.sol"; 
import "../equity//ERC4626Redemption.sol"; 

/// @notice Implement tranches from the vault side
/// @notice influenced by a ERC4626 multi-vault standard, something like this: https://github.com/superform-xyz/experimental-4626/blob/main/contracts/MultiVault.sol
/// @notice Follows ERC4626 debt-vault semantics - see XXX

abstract contract ERC4626Tranche is ERC4626Coupon, ERC4626Redemption {
    using Math for uint256;

    uint8 constant MAX_TRANCHES = 25;

    // Variables
    struct trancheStruct {
        address owner;
        uint32 trancheLTVmaxBPS;
        uint256 trancheMinCoverage;
        uint256 trancheMaxSize;
        uint256 principal;
        uint256 rateBPS; // overloaded as guaranteed rate or % of coupon, depending on guaranteedRate below
        uint256 lastCouponUpdate;
        uint256 couponAccrued;
        uint256 couponEscrowed;
        uint256 principalEscrowed;
        bool rapidAmortization;
        bool guaranteedRate;
        bool autoAccept;
    }
    trancheStruct[] _tranches;
    mapping (address => uint32) _trancheIndex;
    uint256 public totalTranchePrincipal;
    uint256 trancheCouponReserved;
    uint256 tranchePrincipalReserved;

    // Events modeled after multi-vault
    event Deposit(uint256 vaultID, address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(uint256 vaultId, address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
    event WithdrawCoupon(uint256 vaultId, address indexed caller, address indexed receiver, address indexed owner, uint256 assets);

    constructor() {
        // push guard tranche, as tranche 0 is equity
        _tranches.push(trancheStruct(address(0), 10000, 0, 0, 0, 0, 0, 0, 0, 0, false, false, false));
    }

    // Manager Functions - create tranche, set owner, accept deposits, waterfall coupons and repay principal

    // tranches are created in order of seniority, most senior first
    function createTranche(address _owner, uint32 _LTVmax, uint256 _minCoverage, uint256 _maxSize, uint256 _rateBPS, bool _guaranteedRate, bool _autoAccept) public virtual onlyManager returns (uint256 trancheID) {
        trancheID = _tranches.length;
        require(trancheID <= MAX_TRANCHES, "createTranche: exceeded max tranches");
        _tranches.push(trancheStruct(_owner, _LTVmax, _minCoverage, _maxSize, 0, _rateBPS, 0, 0, 0, 0, false, _guaranteedRate, _autoAccept));
    }

    function setVaultOwner(uint256 _vaultID, address _owner) public virtual onlyManager {
        require(_vaultID > 0 && _vaultID < _tranches.length, "setVaultOwner: invalid vault ID");
        _tranches[_vaultID].owner = _owner;
    }

    function acceptTranche(uint256 _vaultID, uint256 _amount) public virtual onlyManager {
        _acceptTranche(_vaultID, _amount);
    }

    function _acceptTranche(uint256 _vaultID, uint256 _amount) internal virtual {
        require(_vaultID > 0 && _vaultID < _tranches.length, "acceptTranche: invalid vault ID");
        if (_amount > _tranches[_vaultID].principalEscrowed) _amount = _tranches[_vaultID].principalEscrowed;
        _updateAccruedCoupon(_vaultID);
        _tranches[_vaultID].principalEscrowed -= _amount;
        _tranches[_vaultID].principal += _amount;
        tranchePrincipalReserved -= _amount;
        emit Deposit(_vaultID, _msgSender(), _tranches[_vaultID].owner, _amount, _amount);
    }

    function  waterfallCoupon () public virtual onlyManager {
        for (uint32 i=1; i<_tranches.length && trancheCouponReserved > 0; i++) {
            _waterfallCouponIndex(i);
        }
        if (trancheCouponReserved > 0) { // distribute remaining coupon to equity
            uint256 couponRemaining = trancheCouponReserved;
            trancheCouponReserved = 0; // have to do this to "free" the funds before distributing the coupon
            ERC4626Coupon.distributeCoupon(couponRemaining);
        }
    }

    function repayTranche(uint256 _vaultID, uint256 _amount) public virtual onlyManager returns (uint256) {
        require(_vaultID > 0 && _vaultID < _tranches.length, "acceptTranche: invalid vault ID");
        require(_amount > availableAssets(), "repayTranche: not enough assets");
        if (_amount > _tranches[_vaultID].principal) _amount = _tranches[_vaultID].principal;
        _updateAccruedCoupon(_vaultID);
        _tranches[_vaultID].principal -= _amount;
        _tranches[_vaultID].principalEscrowed += _amount;
        tranchePrincipalReserved += _amount;
        return _amount;
    }

    function repayAllTranches(uint256 _amount) public virtual onlyManager returns (uint256) {
        require(_amount > availableAssets(), "repayAllTranches: not enough assets");
        for (uint32 i=1; i<_tranches.length && _amount > 0; i++) {
            _amount -= repayTranche(i, _amount);
        }
        return _amount;
    }

    function checkRedeemInvariants(uint256 _trancheID, uint256 _toRedeem) public virtual view returns (bool) {
        if (_trancheID == 0) _trancheID = _tranches.length;
        uint256 totAssets = totalAssets() - _toRedeem;
        for (uint256 i=1; i<_trancheID; i++) {
            if (!_checkInvariants(i, totAssets)) return false;
            totAssets -= _tranches[i].principal;
        }
        return true;
    }

    // Manager functions overriden from elsewhere

    // hold all coupon payments until manager calls waterfallCoupon
    function distributeCoupon(uint256 _coupon) internal virtual override onlyManager {
        require(availableAssets() >= _coupon, "distributeCoupon: not enough assets");
        trancheCouponReserved += _coupon;
        for (uint32 i=1; i<_tranches.length; i++) {
            if (!_tranches[i].guaranteedRate) {
                // this tranche is not guaranteed, so accrue its % of the coupon
                // coupon amount is % of total assets, so in debt/equity fund this might not be what you want
                _tranches[i].couponAccrued += 
                    _coupon.mulDiv(_tranches[i].principal, totalAssets())
                            .mulDiv(_tranches[i].rateBPS, BPS_MULTIPLE);
                _tranches[i].lastCouponUpdate = block.timestamp;
            }
        }
    }

    function distributeRedemption (uint256 _assets, uint256 _shares) public virtual override onlyManager {
        require(checkRedeemInvariants(0, _assets), "distributeRedemption: invariants not met");
        super.distributeRedemption(_assets, _shares);
    }

    // disallow single owner redemptions if invariants are not met
    function distributeOneRedemption(address _owner, uint256 _assets, uint256 _shares) public virtual override onlyManager {
        require(checkRedeemInvariants(0, _assets), "distributeOneRedemption: invariants not met");
        super.distributeOneRedemption(_owner, _assets, _shares);
    }


    function _checkInvariants(uint256 _trancheID, uint256 _totalAssets) internal virtual view returns (bool) {
        return (_totalAssets >= _tranches[_trancheID].principal) && // only happens when tranche is underwater
                (_totalAssets - _tranches[_trancheID].principal >= _tranches[_trancheID].trancheMinCoverage) && 
                (_tranches[_trancheID].principal.mulDiv(BPS_MULTIPLE, _totalAssets) >= _tranches[_trancheID].trancheLTVmaxBPS);
    }

    function _computeAccruedCoupon(uint256 index) internal virtual view returns (uint256) {
        if (_tranches[index].guaranteedRate) {
            return _tranches[index].principal.mulDiv(_tranches[index].rateBPS * 
                        (_tranches[index].lastCouponUpdate - block.timestamp), BPS_MULTIPLE);
        }
        return 0;
    }

    function _updateAccruedCoupon(uint256 index) internal virtual {
        if (_tranches[index].guaranteedRate) {
            _tranches[index].couponAccrued += _computeAccruedCoupon(index);
            _tranches[index].lastCouponUpdate = block.timestamp;
        }
    }

    function  _waterfallCouponIndex(uint32 index) internal virtual {
        _updateAccruedCoupon(index);
        uint256 couponToEscrow = Math.min(_tranches[index].couponAccrued, trancheCouponReserved);
        _tranches[index].couponAccrued -= couponToEscrow;
        trancheCouponReserved -= couponToEscrow;
        _tranches[index].couponEscrowed += couponToEscrow;
        if (_tranches[index].rapidAmortization && trancheCouponReserved > 0) {
            uint256 amort = Math.min(_tranches[index].principal, trancheCouponReserved);
            trancheCouponReserved -= amort;
            repayTranche(index, amort);
        }
    }

    // functions to be called by the tranche vault - following ERC4626 multi-vault function signatures, and debt-vault semantics
    // deposit into escrow, withdraw principal from escrow, and withdraw coupons

    /*///////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function withdrawCoupon (uint256 _vaultID, uint256 _amount, address _receiver, address _owner) public virtual returns (uint256) {
        if (_vaultID == 0) return withdrawCoupon(_amount, _receiver, _owner);
        require (_msgSender() == _owner, "withdrawCoupon: not owner");
        uint256 avail = maxWithdrawCoupon(_vaultID, _owner);
        if (_amount > avail) _amount = avail;
        _tranches[_vaultID].couponEscrowed -= _amount; // safe because of above check
        trancheCouponReserved -= _amount;
        require(IERC20(asset()).transfer(_receiver, _amount), "withdrawCoupon: Transfer failed");
        emit WithdrawCoupon(_vaultID, _msgSender(), _receiver, _owner, _amount);
        return _amount;
    }

    function deposit(uint256 _vaultID, uint256 _amount, address _receiver) public returns (uint256) {
        if (_vaultID == 0) return deposit(_amount, _receiver);
        require (_receiver == _tranches[_vaultID].owner, "deposit: receiver must be tranche owner");
        require (_amount <= maxDeposit(_receiver), "deposit: amount exceeds max");
        _updateAccruedCoupon(_vaultID);
        address sender = _msgSender();
        require(IERC20(asset()).transferFrom(sender, address(this), _amount), "deposit: transfer failed");
        _tranches[_vaultID].principalEscrowed += _amount;
        tranchePrincipalReserved += _amount;
        if (_tranches[_vaultID].autoAccept) _acceptTranche(_vaultID, _amount);
        return _amount;
    }

    function mint(uint256 _vaultID, uint256 _amount, address _receiver) public returns (uint256) {
        if (_vaultID == 0) return mint(_amount, _receiver);        
        return deposit(_vaultID, _amount, _receiver);
    }

    // debt-vault semantics: Withdraw gets both coupon and principal, starting with coupon, redeem just gets principal
    function withdraw(uint256 _vaultID, uint256 _amount, address _receiver, address _owner) public returns (uint256 shares) {
        if (_vaultID == 0) return withdraw(_amount, _receiver, _owner);
        require (_msgSender() == _owner, "withdraw: not owner");
        require(_amount > 0 && _amount <= maxWithdraw(_owner), "withdraw: amount zero or excceds max");
        uint256 couponAmount = Math.min(_amount, _tranches[_vaultID].couponEscrowed);
        if (couponAmount > 0) {
            _tranches[_vaultID].couponEscrowed -= couponAmount; // safe because of above min check
            trancheCouponReserved -= couponAmount;
        }
        uint256 principalAmount = _amount - couponAmount;
        if (principalAmount > 0) {
            _tranches[_vaultID].principalEscrowed -= principalAmount; // safe because of maxWithdraw check
            tranchePrincipalReserved -= principalAmount;
        }
        require(IERC20(asset()).transfer(_receiver, _amount), "withdraw: Transfer failed");
        emit Withdraw(_vaultID, _msgSender(), _receiver, _owner, _amount, principalAmount);
        return principalAmount;
    }

    function redeem(uint256 _vaultID, uint256 _amount, address _receiver, address _owner) public returns (uint256 assets)  {
        if (_vaultID == 0) return redeem(_amount, _receiver, _owner);
        require (_msgSender() == _owner, "redeem: not owner");
        require(_amount > 0 && _amount <= maxRedeem(_owner), "redeem: amount zero or excceds max");
        _tranches[_vaultID].principalEscrowed -= _amount; // safe because of maxRedeem check
        tranchePrincipalReserved -= _amount;
        require(IERC20(asset()).transfer(_receiver, _amount), "redeem: Transfer failed");
        emit Withdraw(_vaultID, _msgSender(), _receiver, _owner, _amount, _amount);
        return _amount;
    }

    /*///////////////////////////////////////////////////////////////
                           ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function convertToShares(uint256 vaultId, uint256 assets) public view virtual returns (uint256) {
        if (vaultId == 0) return convertToShares(assets);
        require(vaultId < _tranches.length, "invalid vault ID");        
        return assets;
    }

    function convertToAssets(uint256 vaultId, uint256 shares) public view virtual returns (uint256) {
        if (vaultId == 0) return convertToAssets(shares);
        require(vaultId < _tranches.length, "invalid vault ID");        
        return shares;
    }

    function previewDeposit(uint256 vaultId, uint256 assets) public view virtual returns (uint256) {
        if (vaultId == 0) return previewDeposit(assets);
        require(vaultId < _tranches.length, "invalid vault ID");        
        return assets;
    }

    function previewMint(uint256 vaultId, uint256 shares) public view virtual returns (uint256) {
        if (vaultId == 0) return previewMint(shares);
        require(vaultId < _tranches.length, "invalid vault ID");        
        return shares;
    }

    function previewWithdraw(uint256 vaultId, uint256 assets) public view virtual returns (uint256) {
        if (vaultId == 0) return previewWithdraw(assets);
        require(vaultId < _tranches.length, "invalid vault ID");        
        return assets;
    }

    function previewRedeem(uint256 vaultId, uint256 shares) public view virtual returns (uint256) {
        if (vaultId == 0) return previewRedeem(shares);
        require(vaultId < _tranches.length, "invalid vault ID");        
        return shares;
    }

    /*///////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function maxDeposit(uint256 _vaultID, address _owner) public view returns (uint256 max) {
        if (_vaultID == 0) return maxDeposit(_owner);
        require (_vaultID < _tranches.length, "invalid vault ID");
        require(_tranches[_vaultID].owner == _owner, "vaultID does not match owner");
        uint256 totAssets = totalAssets();
        for (uint256 i=1; i<_vaultID; i++) {
            if (totAssets < _tranches[i].principal) return 0;
            totAssets -= _tranches[i].principal;
        }
        if (!_checkInvariants(_vaultID, totAssets)) return 0;
        return Math.min(totAssets.mulDiv(_tranches[_vaultID].trancheLTVmaxBPS, BPS_MULTIPLE) - _tranches[_vaultID].principal,
                    _tranches[_vaultID].trancheMaxSize - _tranches[_vaultID].principal);
    }

    function maxMint(uint256 _vaultID, address _owner) public view returns (uint256) {
        if (_vaultID == 0) return maxMint(_owner);
        return maxDeposit(_vaultID, _owner);
    }

    function maxWithdraw(uint256 _vaultID, address _owner) public view returns (uint256) {
        if (_vaultID == 0) return maxMint(_owner);
        require (_vaultID < _tranches.length, "invalid vault ID");
        require(_tranches[_vaultID].owner == _owner, "vaultID does not match owner");
        return maxRedeem(_vaultID, _owner) + maxWithdrawCoupon(_vaultID, _owner);
    }

    function maxRedeem(uint256 _vaultID, address _owner) public view returns (uint256) {
        if (_vaultID == 0) return maxMint(_owner);
        require (_vaultID < _tranches.length, "invalid vault ID");
        require(_tranches[_vaultID].owner == _owner, "vaultID does not match owner");
        return _tranches[_vaultID].principalEscrowed;
    }

    function maxWithdrawCoupon(uint256 _vaultID, address _owner) public virtual view returns (uint256) {
        if (_vaultID == 0) return maxWithdrawCoupon(_owner);
        require (_vaultID < _tranches.length, "invalid vault ID");
        require(_tranches[_vaultID].owner == _owner, "vaultID does not match owner");
        return _tranches[_vaultID].couponEscrowed;
    }

    function balanceOf(uint256 _vaultID, address _owner) public virtual view returns (uint256) {
        if (_vaultID == 0) return maxWithdrawCoupon(_owner);
        require (_vaultID < _tranches.length, "invalid vault ID");
        require(_tranches[_vaultID].owner == _owner, "vaultID does not match owner");
        return _tranches[_vaultID].principal + maxRedeem(_vaultID, _owner);
    }

    // overrides for accounting

    function totalLiabilities() public virtual override view returns (uint256) {
        return super.totalLiabilities() + totalTranchePrincipal;
    }

    function availableAssets() public virtual override(ERC4626Coupon, ERC4626Redemption) view returns (uint256 avail) {
        avail = super.availableAssets();
        assert(avail >= trancheCouponReserved + tranchePrincipalReserved); // should never get here
        unchecked {
            avail -= trancheCouponReserved + tranchePrincipalReserved;
        }
    }

    // everything from here down is to satisfy the compiler about multiple inheritance
   function totalSupply() public view virtual override(ERC20, ERC4626Redemption) returns (uint256) {
        return super.totalSupply();
    }
    function maxWithdraw(address owner) public view virtual override(ERC4626, ERC4626Redemption) returns (uint256) {
        return super.maxWithdraw(owner);
    }

    function maxRedeem(address owner) public view virtual override(ERC4626, ERC4626Redemption) returns (uint256) {
        return super.maxRedeem(owner);
    }

    /** @dev See {IERC4626-previewWithdraw}. */
    function previewWithdraw(uint256 assets) public view virtual override(ERC4626, ERC4626Redemption) returns (uint256) {
        return super.previewWithdraw(assets);
    }

    /** @dev See {IERC4626-previewRedeem}. */
    function previewRedeem(uint256 shares) public view virtual override(ERC4626, ERC4626Redemption) returns (uint256) { 
        return super.previewRedeem(shares);
    }

    /** @dev See {IERC4626-withdraw}. */
    function withdraw(uint256 assets, address receiver, address owner
    ) public virtual override(ERC4626, ERC4626Redemption) returns (uint256 ) {
        return super.withdraw(assets, receiver, owner);
    }

    /** @dev See {IERC4626-redeem}. */
    function redeem(uint256 shares, address receiver, address owner
    ) public virtual override(ERC4626, ERC4626Redemption) returns (uint256) {
        return super.redeem(shares, receiver, owner);
    }

    // be sure to update reserved redemption before any share count changes
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC4626Coupon, ERC4626Redemption) {
        super._beforeTokenTransfer(from, to, amount);
    }

}
