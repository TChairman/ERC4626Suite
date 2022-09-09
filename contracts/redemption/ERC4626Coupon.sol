// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "../ERC4626SuiteContext.sol"; 

/// @notice Implement payment of coupons for ERC4626 vaults. Can also be used for dividends.

abstract contract ERC4626Coupon is ERC4626SuiteContext {
    using Math for uint256;

    // Variables
    uint256 public totalCouponPaid;
    uint256 public couponAssetsReserved;
    struct couponType {
        uint256 remainingCoupon;
        uint256 lastTotalCoupon;
    }
    mapping (address => couponType) _coupons;

    // Events
    event couponDistributedEvent(uint256 coupon);

    constructor() {
    }

    function distributeCoupon(uint256 _coupon) internal virtual onlyManager {
        require(availableAssets() >= _coupon, "distributeCoupon: not enough assets");
        totalCouponPaid += _coupon;
        couponAssetsReserved += _coupon;
        emit couponDistributedEvent(_coupon);
    }

    function couponBalance(address owner) public virtual view returns (uint256) {
        uint256 totSup = totalSupply();
        if (totSup == 0) return 0;
        return _coupons[owner].remainingCoupon + (totalCouponPaid - _coupons[owner].lastTotalCoupon).mulDiv(balanceOf(owner), totSup);
    }

    function updateCouponBalance(address owner) public virtual returns (uint256) {
        uint256 totSup = totalSupply();
        if (totSup == 0) return 0;
        _coupons[owner].lastTotalCoupon = totalCouponPaid;
        return _coupons[owner].remainingCoupon = couponBalance(owner);
    }

    function claimCoupon (address owner, address to, uint256 amount) public virtual {
        uint256 avail = couponBalance(owner);
        if (amount > avail) amount = avail;
        _coupons[owner].lastTotalCoupon = totalCouponPaid;
        _coupons[owner].remainingCoupon = avail - amount; // safe because of above check
        couponAssetsReserved -= amount;
        require(IERC20(asset()).transfer(to, amount), "claimCoupon: Transfer failed");
    }

    // use this in totalAssets() instead of asset.balanceOf(this)
    function availableAssets() public virtual override view returns (uint256 avail) {
        avail = super.availableAssets();
        assert(avail >= couponAssetsReserved); // should never get here
        unchecked {
            avail -= couponAssetsReserved;
        }
    }

    // be sure to update coupon balances before changing underlying token balances
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (to != address(0)) updateCouponBalance(to);
        if (from != address(0)) updateCouponBalance(from);
        super._beforeTokenTransfer(from, to, amount);
    }

}
