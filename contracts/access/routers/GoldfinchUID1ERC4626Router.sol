// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

/// @notice ERC4626 Router that implements Goldfinch KYC and accredited restrictions (UID 1). ERC4626 vaults can allow list this router to enable all Goldfinch KYC UIDs to transact.

import "./ERC4626AccessRouter.sol";
import {IERC1155} from "./external/interfaces/IERC1155.sol";

string constant CONTRACT_NAME = "goldfinchUID1.4626access.eth";

address constant UID_CONTRACT = 0xba0439088dc1e75F58e0A7C107627942C15cbb41;
uint256 constant ID_VERSION = 1;


contract goldfinchUID1router is ERC4626AccessRouter {

    constructor() ERC4626AccessRouter(CONTRACT_NAME) {}

    function isAllowed(address userAddress) public view override returns (bool) {
        uint256 balance = IERC1155(UID_CONTRACT).balanceOf(userAddress, ID_VERSION);
        return balance > 0;
    }

}