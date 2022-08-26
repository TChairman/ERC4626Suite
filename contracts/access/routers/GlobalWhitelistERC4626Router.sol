// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

/// @notice ERC4626 Router that implements a simple whitelist. Enables sharing whitelists across ERC4626 vaults.

import "./ERC4626AccessRouter.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract GlobalWhitelistERC4626Router is ERC4626AccessRouter, AccessControl {

    string public constant CONTRACT_NAME = "genericaccess.4626access.eth"; // put name here for a specific implementation
    bytes32 public constant WHITELISTED_ROLE = keccak256("WHITELISTED");

    // TODO: update constructor to accept array of addresses for initial whitelist.
    constructor() ERC4626AccessRouter(CONTRACT_NAME) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function isAllowed(address userAddress) public view override returns (bool) {
        return hasRole(WHITELISTED_ROLE, userAddress);
    }

    function whitelist(address userAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not an admin");
        grantRole(WHITELISTED_ROLE, userAddress);
    }

    function whitelistMany(address[] memory addresses) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not an admin");
        for (uint i=0; i<addresses.length; i++) {
            whitelist(addresses[i]);
        }
    }

    function revoke(address userAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not an admin");
        revokeRole(WHITELISTED_ROLE, userAddress);
    }

    function revokeMany(address[] memory addresses) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not an admin");
        for (uint i=0; i<addresses.length; i++) {
            revoke(addresses[i]);
        }
    }

}
