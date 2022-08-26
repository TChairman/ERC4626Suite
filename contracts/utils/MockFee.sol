// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "../fees/ERC4626Fee.sol";

/// @notice Vault instantiation for testing

contract MockFee is ERC4626Fee {
    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        uint32 _annualFeeBPS, 
        uint32 _carryFeeBPS, 
        uint32 _withdrawFeeBPS, 
        bool _disableDiscretionaryFee, 
        bool _disableFeeAdvance
    ) ERC4626(_asset) ERC20(_name, _symbol) 
      ERC4626Fee(_annualFeeBPS, _carryFeeBPS, _withdrawFeeBPS, _disableDiscretionaryFee, _disableFeeAdvance)
    {}

}