// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

/// @notice an enumerable version of ERC4626 to keep a list of investor wallets. Important for regulations in some jurisdictions.

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract ERC4626Enumerable is ERC4626 {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet _investors;

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

    function investorCount() internal view returns (uint256) {
        return _investors.length();
    }

    function investorAt(uint256 idx) internal view returns (address, uint256) {
        address addr = _investors.at(idx);
        return (addr, balanceOf(addr));
    }

}