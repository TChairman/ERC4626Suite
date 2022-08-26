// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "../access/ERC4626BasicAccess.sol";

/// @notice Vault instantiation for testing
/// @author CareWater (https://github.com/CareWater333/ERC4626WithdrawFee)

contract MockBasicAccess is ERC4626BasicAccess {

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset) ERC20(_name, _symbol) {}

}