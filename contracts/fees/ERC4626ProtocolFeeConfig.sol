// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

/// @notice ERC4626 configuration for protocol fees, which can be taken as any of fee types: annual, carry, or withdraw

abstract contract ERC4626ProtocolFeeConfig {

    // ensure all fees are < 100%
    uint32 constant protocolAnnualFeeBPS = 0;
    uint32 constant protocolCarryFeeBPS = 0;
    uint32 constant protoocolWithdrawFeeBPS = 0;
    address public protocolTreasury = address(0);

}