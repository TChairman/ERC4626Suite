// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "./ERC4626Coupon.sol"; 
import "./ERC4626Redemption.sol"; 

/// @notice Implement payment of coupons for ERC4626 vaults. Can also be used for dividends.

abstract contract ERC4626Tranche is ERC4626Coupon, ERC4626Redemption {
    using Math for uint256;

    // Variables
    uint256 public trancheCouponReserved;
    struct trancheStruct {
        address vault;
        uint256 trancheLTVmax;
        uint256 principal;
        uint256 guaranteedRateBPS;
        uint256 lastCouponUpdate;
        uint256 accruedCoupon;
        bool rapidAmortization;
    }
    trancheStruct[] _tranches;
    mapping (address => uint32) _trancheIndex;

    constructor() {
    }

    function createTranche() public virtual onlyManager {

    }

    // hold all coupon payments until manager calls pushTranches
    function distributeCoupon(uint256 _coupon) internal virtual override onlyManager {
        require(availableAssets() >= _coupon, "distributeCoupon: not enough assets");
        trancheCouponReserved += _coupon;
    }

    function updateAccruedCoupon(uint32 index) public virtual {
        _tranches[index].accruedCoupon +=
                _tranches[index].principal.mulDiv(_tranches[index].guaranteedRateBPS * 
                    (_tranches[index].lastCouponUpdate - block.timestamp), BPS_MULTIPLE);
        _tranches[index].lastCouponUpdate = block.timestamp;
    }

    function  pushTrancheCoupon(uint32 index) public virtual onlyManager {
        updateAccruedCoupon(index);
        uint256 couponToPush = Math.min(_tranches[index].accruedCoupon, trancheCouponReserved);
        _tranches[index].accruedCoupon -= couponToPush;
        trancheCouponReserved -= couponToPush;
        require(IERC20(asset()).transfer(_tranches[index].vault, couponToPush), "transfer failed");
        // TODO do some callback to the vault here
        if (_tranches[index].rapidAmortization && trancheCouponReserved > 0) {
            uint256 amort = Math.min(_tranches[index].principal, trancheCouponReserved);
            trancheAmortization(index, amort);
            trancheCouponReserved -= amort;
        }
    }

    function  pushAllTrancheCoupons () public virtual onlyManager {
        for (uint32 i=0; i<_tranches.length && trancheCouponReserved > 0; i++) {
            pushTrancheCoupon(i);
        }
        if (trancheCouponReserved > 0) {
            uint256 couponRemaining = trancheCouponReserved;
            trancheCouponReserved = 0; // have to do this to "free" the funds before distributing the coupon
            ERC4626Coupon.distributeCoupon(couponRemaining);
        }
    }

    function trancheAmortization(uint32 index, uint256 amount) public virtual onlyManager {

    }

    function checkTrancheInvariants() internal virtual {

    }
    function issueRedemption (uint256 _shares, uint256 _assets) public virtual override onlyManager {
        checkTrancheInvariants();
        super.issueRedemption(_shares, _assets);
    }
    function issueOneRedemption(address _owner, uint256 _assets, uint256 _shares) public virtual override onlyManager {
        checkTrancheInvariants();
        super.issueOneRedemption(_owner, _shares, _assets);
    }

    function availableAssets() public virtual override(ERC4626Coupon, ERC4626Redemption) view returns (uint256 avail) {
        avail = super.availableAssets();
        assert(avail >= trancheCouponReserved); // should never get here
        unchecked {
            avail -= trancheCouponReserved;
        }
    }

    // everything from here down is to satisfy the compiler about multiple inheritance
   function totalSupply() public view virtual override(ERC20, ERC4626Redemption) returns (uint256) {
        return super.totalSupply();
    }
    function maxWithdraw(address owner) public view virtual override(ERC4626, ERC4626Redemption) returns (uint256 assets) {
        return super.maxWithdraw(owner);
    }

    function maxRedeem(address owner) public view virtual override(ERC4626, ERC4626Redemption) returns (uint256 shares) {
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
    ) public virtual override(ERC4626, ERC4626Redemption) returns (uint256 shares) {
        super.withdraw(assets, receiver, owner);
    }

    /** @dev See {IERC4626-redeem}. */
    function redeem(uint256 shares, address receiver, address owner
    ) public virtual override(ERC4626, ERC4626Redemption) returns (uint256 assets) {
        super.redeem(shares, receiver, owner);
    }

    // be sure to update reserved redemption before any share count changes
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC4626Coupon, ERC4626Redemption) {
        super._beforeTokenTransfer(from, to, amount);
    }

}
