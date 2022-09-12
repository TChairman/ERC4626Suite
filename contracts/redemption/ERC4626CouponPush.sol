// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "./ERC4626Coupon.sol"; 
import "../ERC4626Enumerable.sol";

/// @notice Enable pushing of coupons and dividends directly to investor wallets. Basically an airdrop.

abstract contract ERC4626CouponPush is ERC4626Coupon, ERC4626Enumerable {

    function pushSomeCoupons(uint256 numToPush) public virtual returns (bool) {
        uint256 len = investorCount();
        uint256 i = 0;
        address addr;
        while ((numToPush > 0) && (i < len)) {
            addr = investorAt(i);
            if (couponBalance(addr) > 0) {
                pushCoupon(addr);
                numToPush--;
            }
            i++;
        }
        return i == len;
    }

    function pushCoupon(address owner) public virtual {
        claimCoupon(owner, owner, type(uint256).max);
    }

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
