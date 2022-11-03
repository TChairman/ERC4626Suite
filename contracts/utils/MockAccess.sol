// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author The Chairman (https://github.com/TChairman/ERC4626Suite)

import "../equity/ERC4626Access.sol";

/// @notice Vault instantiation for testing

contract MockAccess is ERC4626Access {
    
    constructor(
        IERC20Metadata _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset) ERC20(_name, _symbol) {}

}
