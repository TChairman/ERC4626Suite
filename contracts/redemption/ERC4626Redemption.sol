// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "../ERC4626SuiteContext.sol";

/// @notice ERC4626 redemption mechanism that replaces the withdraw functions to allow complete manager control of redemptions,
/// @notice both individually and across the portfolio. Includes an optional redemption penalty. Does not currently work with withdraw and carry fees.

abstract contract ERC4626Redemption is ERC4626SuiteContext {
    using Math for uint256;

    struct investorRedemptionType {
        uint256 sharesToRedeem;
        uint256 assetsToRedeem;
        uint256 lastFundRedemption;
    }
    mapping (address => investorRedemptionType) _investorRedemptions;

    struct fundRedemptionType {
        uint256 shares;
        uint256 assets;
        uint256 totalShares;
    }
    fundRedemptionType[] _fundRedemptions;

    uint256 public redemptionAssetsReserved;
    uint256 public redemptionSharesReserved;
    uint256 public redemptionPenaltyReserved;
    uint32 public redemptionPenaltyBPS;

    constructor() {
    }

    function setRedemptionPenaltyBPS (uint32 _newPenaltyBPS) public virtual onlyManager returns (uint32 _oldPenaltyBPS) {
        require(_newPenaltyBPS < BPS_MULTIPLE, "redemptionPenaltyBPS cannot be more than 100%");
        _oldPenaltyBPS = redemptionPenaltyBPS;
        redemptionPenaltyBPS = _newPenaltyBPS;
    }

    function claimRedemptionPenalty(address to, uint256 amount) public virtual onlyManager {
        if (amount > redemptionPenaltyReserved) amount = redemptionPenaltyReserved;
        if (to != address(0)) {
            require(IERC20(asset()).transferFrom(address(this), to, amount), "claimRedemptionPenalty: transfer failed");
        }
        unchecked {
            redemptionPenaltyReserved -= amount;
        }
    }

    function reserveRedemptionPenalty (uint256 _assets) internal virtual returns (uint256) {
        uint256 penalty = _assets.mulDiv(redemptionPenaltyBPS, BPS_MULTIPLE);
        redemptionPenaltyReserved += penalty;
        return _assets - penalty;
    }

    function computeFundRedemption (address owner) public view virtual returns (uint256 _shares, uint256 _assets) {
        uint256 index = _investorRedemptions[owner].lastFundRedemption;
        uint256 len = _fundRedemptions.length;
        if (index < len) {
            uint256 ownerShares = balanceOf(owner) - _investorRedemptions[owner].sharesToRedeem;
            if (ownerShares > 0) {
                _shares = 0; _assets = 0; // need to do this? if not will likely get optimized out anyway
                do {
                    _shares += _fundRedemptions[index].shares.mulDiv(ownerShares, _fundRedemptions[index].totalShares);
                    _assets += _fundRedemptions[index].assets.mulDiv(ownerShares, _fundRedemptions[index].totalShares);
                    index++;
                } while (index < len);
            }
        }
    }

    function updateRedemption (address owner) public virtual {
        (uint256 shares, uint256 assets) = computeFundRedemption(owner);
        _investorRedemptions[owner].sharesToRedeem += shares;
        _investorRedemptions[owner].assetsToRedeem += assets;
        _investorRedemptions[owner].lastFundRedemption = _fundRedemptions.length;
    }

    // override to make sure convertToShares etc account correctly for redemptions
    function totalSupply() public view virtual override returns (uint256) {
        return super.totalSupply() - redemptionSharesReserved;
    }

    // contracts that inherit both this and Coupon will need to override this with both reserved numbers, something like:
    // return IERC20(asset()).balanceOf(address(this)) - redemptionAssetsReserved() - couponAssetsReserved();
    function availableAssets() public virtual override view returns (uint256 avail) {
        avail = super.availableAssets();
        assert (avail >= redemptionAssetsReserved + redemptionPenaltyReserved);
        unchecked {
            avail -= redemptionAssetsReserved + redemptionPenaltyReserved;
        }
    }

    // issue a redemption proportionally to all investors
    function issueRedemption (uint256 _shares, uint256 _assets) public virtual onlyManager {
        _assets = reserveRedemptionPenalty(_assets);
        require(availableAssets() >= _assets, "issueRedemption: not enough assets");
        uint256 availSup = totalSupply();
        require(availSup >= _shares, "issueRedemption: not enough shares");
        redemptionAssetsReserved += _assets;
        redemptionSharesReserved += _shares;
        _fundRedemptions.push(fundRedemptionType(_shares, _assets, availSup));
    }

    // helper function - could move to front end to save contract size
    function issueAssetRedemption (uint256 _assets) public virtual onlyManager {
        issueRedemption(_assets, convertToShares(_assets));
    }

    // helper function - could move to front end to save contract size
    function issueShareRedemption (uint256 _shares) public virtual onlyManager {
        issueRedemption(convertToAssets(_shares), _shares);
    }

    // issue a redemption to one investor
    function issueOneRedemption(address _owner, uint256 _assets, uint256 _shares) public virtual onlyManager {
        updateRedemption(_owner); // important to update share count first
        _assets = reserveRedemptionPenalty(_assets);
        require(availableAssets() >= _assets, "issueOneRedemption: not enough assets");
        require(totalSupply() >= _shares, "issueOneRedemption: not enough shares");
        redemptionAssetsReserved += _assets;
        redemptionSharesReserved += _shares;
        _investorRedemptions[_owner].assetsToRedeem += _assets;
        _investorRedemptions[_owner].sharesToRedeem += _shares;
    }

    // helper function to save gas
    function issueRedemptionArray(address[] memory _redemptionOwners, uint256[] memory _redemptionAmounts) public virtual onlyManager {
        uint256 len = _redemptionOwners.length;
        require (len == _redemptionAmounts.length, "distributeRedemptionArray: lengths don't match");
        for (uint i=0; i<len; i++) {
            issueOneRedemption(_redemptionOwners[i], _redemptionAmounts[i], convertToShares(_redemptionAmounts[i]));
        }
    }

    // all ERC4626 withdraw-related functions only operate on redemptions
    function maxWithdraw(address owner) public view virtual override returns (uint256 assets) {
        (, assets) = computeFundRedemption(owner);
        assets += _investorRedemptions[owner].assetsToRedeem;
    }

    function maxRedeem(address owner) public view virtual override returns (uint256 shares) {
        (shares, ) = computeFundRedemption(owner);
        shares += _investorRedemptions[owner].sharesToRedeem;
   }

    /** @dev See {IERC4626-previewWithdraw}. */
    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        if ((redemptionSharesReserved == 0) || (redemptionAssetsReserved == 0)) {
            return super.previewWithdraw(assets);
        }
        return assets.mulDiv(redemptionSharesReserved, redemptionAssetsReserved, Math.Rounding.Up);
    }

    /** @dev See {IERC4626-previewRedeem}. */
    function previewRedeem(uint256 shares) public view virtual override returns (uint256) { 
        if ((redemptionSharesReserved == 0) || (redemptionAssetsReserved == 0)) {
            return super.previewRedeem(shares);
        }
        return shares.mulDiv(redemptionAssetsReserved, redemptionSharesReserved, Math.Rounding.Down);
    }

    /** @dev See {IERC4626-withdraw}. */
    function withdraw(uint256 assets, address receiver, address owner
    ) public virtual override returns (uint256 shares) {
        updateRedemption(owner);
        require(assets <= _investorRedemptions[owner].assetsToRedeem, "ERC4626: withdraw more than max");
        shares = assets.mulDiv(_investorRedemptions[owner].sharesToRedeem, _investorRedemptions[owner].assetsToRedeem, Math.Rounding.Up);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
        _investorRedemptions[owner].sharesToRedeem -= shares;
        _investorRedemptions[owner].assetsToRedeem -= assets;
    }

    /** @dev See {IERC4626-redeem}. */
    function redeem(uint256 shares, address receiver, address owner
    ) public virtual override returns (uint256 assets) {
        updateRedemption(owner);
        require(shares <= _investorRedemptions[owner].sharesToRedeem, "ERC4626: redeem more than max");
        assets = shares.mulDiv(_investorRedemptions[owner].assetsToRedeem, _investorRedemptions[owner].sharesToRedeem, Math.Rounding.Down);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
        _investorRedemptions[owner].sharesToRedeem -= shares;
        _investorRedemptions[owner].assetsToRedeem -= assets;
    }

    // be sure to update reserved redemption before any share count changes
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        if (from != address(0)) updateRedemption(from);
        if (to != address(0)) updateRedemption(to);
        super._beforeTokenTransfer(from, to, amount);
    }

}