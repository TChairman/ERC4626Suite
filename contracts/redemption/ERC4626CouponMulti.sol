// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "./ERC4626Coupon.sol"; 

/// @notice Implement payment of coupons for ERC4626 multi-vaults. Can also be used for dividends.
/// @notice In this impolementation vaultID 0 is used for equity tranche

abstract contract ERC4626CouponMulti is ERC4626Coupon {
    using Math for uint256;

    // Variables
    uint256[] public totalCouponPaidMulti;
    mapping (address => couponType)[] _couponsMulti;

    // Events
    event distributeCouponMultiEvent(uint256 vaultID, uint256 coupon);
    event withdrawCouponMultiEvent(uint256 vaultID, uint256 amount, address receiver, address owner);

    constructor() {
    }

    //// Investor Functions
    //// Naming is intended to mimic ERC4626Multi:
    //// withdrawCoupon() is same signature as ERC4626 withdraw()
    //// - returns assets actually withdrawn (not shares)
    //// - if more is requested than is available, will withdraw all available (unlike ERC4626)
    //// maxWithdrawCoupon() is same signature as ERC4626 maxWithdraw()

    function maxWithdrawCoupon(uint256 _vaultID, address _owner) public virtual view returns (uint256) {
        if (_vaultID == 0) return maxWithdrawCoupon(_owner);
        uint256 totSup = totalSupply();
        if (totSup == 0) return 0;
        return _couponsMulti[_vaultID][_owner].remainingCoupon + (totalCouponPaidMulti[_vaultID] - _couponsMulti[_vaultID][_owner].lastTotalCoupon).mulDiv(balanceOf(_owner), totSup);
    }

    function withdrawCoupon (uint256 _vaultID, uint256 _amount, address _receiver, address _owner) public virtual returns (uint256) {
        if (_vaultID == 0) return withdrawCoupon(_amount, _receiver, _owner);
        uint256 avail = maxWithdrawCoupon(_vaultID, _owner);
        if (_amount > avail) _amount = avail;
        _couponsMulti[_vaultID][_owner].lastTotalCoupon = totalCouponPaidMulti[_vaultID];
        _couponsMulti[_vaultID][_owner].remainingCoupon = avail - _amount; // safe because of above check
        couponAssetsReserved -= _amount;
        require(IERC20(asset()).transfer(_receiver, _amount), "withdrawCoupon: Transfer failed");
        emit withdrawCouponMultiEvent(_vaultID, _amount, _receiver, _owner);
        return _amount;
    }

    //// Manager Functions

    function distributeCoupon(uint256 _vaultID, uint256 _coupon) internal virtual onlyManager {
        if (_vaultID == 0) return distributeCoupon(_coupon);
        require(availableAssets() >= _coupon, "distributeCoupon: not enough assets");
        totalCouponPaidMulti[_vaultID] += _coupon;
        couponAssetsReserved += _coupon;
        emit distributeCouponMultiEvent(_vaultID, _coupon);
    }

    //// Internal Functions

    function updateCouponBalance(uint256 vaultID, address _owner) internal virtual returns (uint256) {
        if (vaultID == 0) return updateCouponBalance(_owner);
        uint256 totSup = totalSupply();
        if (totSup == 0) return 0;
        _couponsMulti[vaultID][_owner].lastTotalCoupon = totalCouponPaidMulti[vaultID];
        return _couponsMulti[vaultID][_owner].remainingCoupon = maxWithdrawCoupon(vaultID, _owner);
    }

}
