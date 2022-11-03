// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author The Chairman (https://github.com/TChairman/ERC4626Suite)

import "./ERC4626Coupon.sol"; 
import "../ERC4626Enumerable.sol";

/// @notice Enable pushing of coupons and dividends directly to investor wallets. Basically an airdrop.

abstract contract ERC4626CouponPush is ERC4626Coupon, ERC4626Enumerable {

    function pushCoupon(address owner) public virtual {
        withdrawCoupon(type(uint256).max, owner, owner);
    }

    // returns true if all coupons have been pushed, false if there are any left to push
    function pushSomeCoupons(uint256 numToPush) public virtual returns (bool) {
        uint256 len = _addressCount();
        uint256 i = 0;
        address addr;
        while ((numToPush > 0) && (i < len)) {
            addr = _addressAt(i);
            if (maxWithdrawCoupon(addr) > 0) {
                pushCoupon(addr);
                numToPush--;
            }
            i++;
        }
        while (i < len) { // check to see if any remain
            if (maxWithdrawCoupon(addr) > 0) return false;
            i++;
        }
        return true;
    }

    // Everything below here is to satisfy the compiler about multiple inheritance

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC4626Coupon, ERC4626Enumerable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function totalAssets() public view virtual override(ERC4626, ERC4626SuiteContext) returns (uint256) {
        return super.totalAssets();
    }

    function _withdraw (
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override(ERC4626, ERC4626SuiteContext) {
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    function _deposit (
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual override(ERC4626, ERC4626SuiteContext) {
        super._deposit(caller, receiver, assets, shares);
    }

}
