// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

/// @notice ERC4626 vault that provides admin pausing and global disabling of deposits, withdrawals, and transfers

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";    
import "@openzeppelin/contracts/access/AccessControl.sol";

abstract contract ERC4626BasicAccess is ERC4626, AccessControl {

    bool public isPaused;
    bool public depositDisabled;
    bool public withdrawDisabled;
    bool public transferDisabled;

    constructor () {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function pauseVault(bool _pause) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        isPaused = _pause;
    }
    function disableDeposit(bool _deposits) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        depositDisabled = _deposits;
    }
    function disableWithdraw(bool _withdraws) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        withdrawDisabled = _withdraws;
    }
    function disableTransfer(bool _transfers) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        transferDisabled = _transfers;
    }

    function _deposit (
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        require(!isPaused, "Deposit paused");
        require(!depositDisabled, "Deposit disabled");
        super._deposit(caller, receiver, assets, shares);
    }

    function _withdraw (
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        require(!isPaused, "Withdraw paused");
        require(!withdrawDisabled, "Withdraw disabled");
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    // could also override _beforeTokenTransfer hook, but this seems cleaner
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(!isPaused, "Transfer paused");
        require(!transferDisabled, "Transfer disabled");
        super._transfer(from, to, amount);
    }
}
