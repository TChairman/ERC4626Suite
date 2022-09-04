// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "./ERC4626Coupon.sol"; 
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @notice Enable pushing of coupons and dividends directly to investor wallets. Basically an airdrop.
/// @notice Could also base this on ERC426Enumerable, but it was cleaner to just duplicate the code.

abstract contract ERC4626CouponPush is ERC4626Coupon {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet _investors;

    function pushAllCoupons() public virtual {
        pushSomeCoupons(type(uint256).max);
    }

    function pushSomeCoupons(uint256 numToPush) public virtual returns (bool) {
        uint256 len = _investors.length();
        uint256 i = 0;
        address addr;
        while ((numToPush > 0) && (i < len)) {
            addr = _investors.at(i);
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

    function investorCount() internal view returns (uint256) {
        return _investors.length();
    }

    function investorAt(uint256 idx) internal view returns (address, uint256) {
        address addr = _investors.at(idx);
        return (addr, balanceOf(addr));
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (to != address(0)) {
            _investors.add(to);
        }
        super._beforeTokenTransfer(from, to, amount);
    }

}
