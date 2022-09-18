// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

/// @notice This architecture is influenced by https://github.com/fei-protocol/ERC4626/blob/main/src/ERC4626RouterBase.sol
/// @notice Mainly implemented isAllowed() in mint() and deposit(). Transfer functions are also overridden for access control.

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ENSReverseRecord} from "./external/ENSReverseRecord.sol";

abstract contract ERC4626AccessRouter is ENSReverseRecord {

    constructor(string memory ENSname) ENSReverseRecord(ENSname) {}

    function isAllowed(address to) public virtual returns (bool) {}

    function safeTransferFrom(
        IERC20 vault,
        address from,
        address to,
        uint256 amount
    ) public virtual {
        require(isAllowed(to), "Transfer access control failed");
        require(vault.transferFrom(from, to, amount), "Safe Transfer From failed");
    }

    function safeTransfer(
        IERC20 vault,
        address to,
        uint256 amount
    ) public virtual {
        require(isAllowed(to), "Transfer access control failed");
        require(vault.transfer(to, amount), "Safe Transfer failed");
    }

    function transferFrom (
        IERC20 vault,
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        require(isAllowed(to), "Transfer access control failed");
        return vault.transferFrom(from, to, amount);
    }

    function transfer (
        IERC20 vault,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        require(isAllowed(to), "Transfer access control failed");
        return vault.transfer(to, amount);
    }

    function mint(
        IERC4626 vault,
        uint256 shares,
        address to
    ) public virtual returns (uint256 assets) {
        require(isAllowed(to), "Mint access control failed");
        assets = vault.previewMint(shares);
        require(IERC20(vault.asset()).transferFrom(msg.sender, address(this), assets));
        vault.deposit(assets, to); // may not always be the same as vault.mint(shares, to), but this way there's no dust from assets
        // assets = vault.mint(shares, to); // the other option, if mint and deposit have different behavior for some reason
    }

    function deposit(
        IERC4626 vault,
        uint256 amount,
        address to
    ) public virtual returns (uint256 shares) {
        require(isAllowed(to), "Deposit access control failed");
        require(IERC20(vault.asset()).transferFrom(msg.sender, address(this), amount));
        shares = vault.deposit(amount, to);
    }

    function withdraw(
        IERC4626 vault,
        uint256 amount,
        address to,
        address owner
    ) public virtual returns (uint256 shares) {
        shares = vault.withdraw(amount, to, owner);
    }

    function redeem(
        IERC4626 vault,
        uint256 shares,
        address to,
        address owner
    ) public virtual returns (uint256 assets) {
        assets = vault.redeem(shares, to, owner);
    }
}