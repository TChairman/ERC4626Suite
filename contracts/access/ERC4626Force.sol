// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

/// @notice ERC4626 vault that allows an admin to force transfer or force redeem an investor

import "../ERC4626SuiteContext.sol";

abstract contract ERC4626Force is ERC4626SuiteContext {

    event forceTransferFromEvent(address from, address to, uint256 amount);
    event forceRedeemEvent(address owner, uint256 shares);

    constructor() {}

    function forceTransferFrom(address from, address to, uint256 amount) public virtual onlyManager {
        require(transferFrom(from, to, amount), "Force transfer failed");
        emit forceTransferFromEvent(from, to, amount);
    }

    function forceRedeem(address owner, uint256 shares) public virtual onlyManager {
        uint256 maxSh = maxRedeem(owner);
        if (maxSh > shares) shares = maxSh;
        redeem(shares, owner, owner);
        emit forceRedeemEvent(owner, shares);
    }

}
