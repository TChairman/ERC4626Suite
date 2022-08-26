// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "../fees/ERC4626BasicFee.sol";

/// @notice Vault instantiation for testing
/// @author CareWater (https://github.com/CareWater333/ERC4626WithdrawFee)

contract MockBasicFee is ERC4626BasicFee {
    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _managerTreasury,
        uint32 _managerFeeBPS
    ) ERC4626(_asset) ERC20(_name, _symbol) ERC4626BasicFee(_managerTreasury, _managerFeeBPS) {}

}