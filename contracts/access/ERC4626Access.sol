// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

/// @notice ERC4626 vault that allows an admin to selectively enable deposits and withdrawals for individual investors
/// @notice Very powerful when used in conjunction with Access Routers.

import "./ERC4626BasicAccess.sol";

abstract contract ERC4626Access is ERC4626BasicAccess {

    bytes32 public constant DEPOSIT_ROLE = keccak256("DEPOSIT");
    bytes32 public constant WITHDRAW_ROLE = keccak256("WITHDRAW");
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER");
    bool public depositOpen;
    bool public withdrawOpen;
    bool public transferOpen;

    constructor () {
    }

    function openDeposit(bool _deposits) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        depositOpen = _deposits;
    }
    function openWithdraw(bool _withdraws) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        withdrawOpen = _withdraws;
    }
    function openTransfer(bool _transfers) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        transferOpen = _transfers;
    }

    function _deposit (
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        require(depositOpen || hasRole(DEPOSIT_ROLE, msg.sender), "Deposit not authorized");
        super._deposit(caller, receiver, assets, shares);
    }

    function _withdraw (
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        require(withdrawOpen || hasRole(WITHDRAW_ROLE, msg.sender), "Withdraw not authorized");
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    // could also override _beforeTokenTransfer hook, but this seems cleaner
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(transferOpen || hasRole(TRANSFER_ROLE, msg.sender), "Transfer not authorized");
        super._transfer(from, to, amount);
    }
}
