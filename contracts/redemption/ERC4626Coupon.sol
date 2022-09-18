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
    event distributeCouponEvent(uint256 coupon);
    event withdrawCouponEvent(uint256 amount, address receiver, address owner);

    constructor() {
    }

    //// Investor Functions
    //// Naming is intended to mimic ERC4626:
    //// withdrawCoupon() is same signature as ERC4626 withdraw()
    //// - returns assets actually withdrawn (not shares)
    //// - if more is requested than is available, will withdraw all available (unlike ERC4626)
    //// maxWithdrawCoupon() is same signature as ERC4626 maxWithdraw()

    function maxWithdrawCoupon(address _owner) public virtual view returns (uint256) {
        uint256 totSup = totalSupply();
        if (totSup == 0) return 0;
        return _coupons[_owner].remainingCoupon + (totalCouponPaid - _coupons[_owner].lastTotalCoupon).mulDiv(balanceOf(_owner), totSup);
    }

    function withdrawCoupon (uint256 _amount, address _receiver, address _owner) public virtual returns (uint256) {
        require (_msgSender() == _owner, "withdrawCoupon: not owner");
        uint256 avail = maxWithdrawCoupon(_owner);
        if (_amount > avail) _amount = avail;
        _coupons[_owner].lastTotalCoupon = totalCouponPaid;
        _coupons[_owner].remainingCoupon = avail - _amount; // safe because of above check
        couponAssetsReserved -= _amount;
        require(IERC20(asset()).transfer(_receiver, _amount), "withdrawCoupon: Transfer failed");
        emit withdrawCouponEvent(_amount, _receiver, _owner);
        return _amount;
    }

    //// Manager Functions

    function distributeCoupon(uint256 _coupon) internal virtual onlyManager {
        require(availableAssets() >= _coupon, "distributeCoupon: not enough assets");
        totalCouponPaid += _coupon;
        couponAssetsReserved += _coupon;
        emit distributeCouponEvent(_coupon);
    }

    //// Internal Functions

    function updateCouponBalance(address owner) internal virtual returns (uint256) {
        uint256 totSup = totalSupply();
        if (totSup == 0) return 0;
        _coupons[owner].lastTotalCoupon = totalCouponPaid;
        return _coupons[owner].remainingCoupon = maxWithdrawCoupon(owner);
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
