// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

/// @notice ERC4626 Router that implements a simple allow list. Enables sharing allow lists across ERC4626 vaults.

import "./ERC4626AccessRouter.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract GlobalAllowListERC4626Router is ERC4626AccessRouter, AccessControl {

    string public constant CONTRACT_NAME = "allowlist.4626access.eth"; // put name here for a specific implementation
    bytes32 public constant ALLOW_LISTED = keccak256("ALLOW_LISTED");

    // TODO: update constructor to accept array of addresses for initial allowlist.
    constructor() ERC4626AccessRouter(CONTRACT_NAME) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function isAllowed(address userAddress) public view override returns (bool) {
        return hasRole(ALLOW_LISTED, userAddress);
    }

    function allow(address userAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Not an admin");
        grantRole(ALLOW_LISTED, userAddress);
    }

    function allowMany(address[] memory addresses) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Not an admin");
        for (uint i=0; i<addresses.length; i++) {
            allow(addresses[i]);
        }
    }

    function revoke(address userAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Not an admin");
        revokeRole(ALLOW_LISTED, userAddress);
    }

    function revokeMany(address[] memory addresses) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Not an admin");
        for (uint i=0; i<addresses.length; i++) {
            revoke(addresses[i]);
        }
    }

}
