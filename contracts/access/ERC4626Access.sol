// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

/// @notice ERC4626 vault that allows an admin to selectively enable deposits and withdrawals for individual investors
/// @notice Very powerful when used in conjunction with Access Routers.

import "../ERC4626SuiteContext.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


abstract contract ERC4626Access is ERC4626SuiteContext, AccessControl, Pausable {

    enum accessType {
        open,
        allowList,
        blockList,
        closed
    }

    accessType public depositMintAccess;
    accessType public withdrawRedeemAccess;
    accessType public transferAccess;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant DEPOSIT_ALLOWLIST = keccak256("DEPOSIT_ALLOWLIST");
    bytes32 public constant DEPOSIT_BLOCKLIST = keccak256("DEPOSIT_BLOCKLIST");
    bytes32 public constant WITHDRAW_ALLOWLIST = keccak256("WITHDRAW_ALLOWLIST");
    bytes32 public constant WITHDRAW_BLOCKLIST = keccak256("WITHDRAW_ALLOWLIST");
    bytes32 public constant TRANSFER_ALLOWLIST = keccak256("TRANSFER_ALLOWLIST");
    bytes32 public constant TRANSFER_BLOCKLIST = keccak256("TRANSFER_ALLOWLIST");

    event depositMintAccessChanged(address by, accessType to);
    event withdrawRedeemAccessChanged(address by, accessType to);
    event transferAccessChanged(address by, accessType to);

    constructor () {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MANAGER_ROLE, _msgSender());
        _setRoleAdmin(DEPOSIT_ALLOWLIST, MANAGER_ROLE);
        _setRoleAdmin(DEPOSIT_BLOCKLIST, MANAGER_ROLE);
        _setRoleAdmin(WITHDRAW_ALLOWLIST, MANAGER_ROLE);
        _setRoleAdmin(WITHDRAW_BLOCKLIST, MANAGER_ROLE);
        _setRoleAdmin(TRANSFER_ALLOWLIST, MANAGER_ROLE);
        _setRoleAdmin(TRANSFER_BLOCKLIST, MANAGER_ROLE);
        depositMintAccess = accessType.open;
        withdrawRedeemAccess = accessType.open;
        transferAccess = accessType.open;
    }

    // enable changing access by managers
    function setDepositMintAccess(accessType _acc) public virtual onlyManager {
        depositMintAccess = _acc;
        emit depositMintAccessChanged(_msgSender(), _acc);
    }

    function setWithdrawRedeemAccess(accessType _acc) public virtual onlyManager {
        withdrawRedeemAccess = _acc;
        emit withdrawRedeemAccessChanged(_msgSender(), _acc);
    }

    function setTransferAccess(accessType _acc) public virtual onlyManager {
        transferAccess = _acc;
        emit transferAccessChanged(_msgSender(), _acc);
    }

    // add basic pause functionality now that we have roles to protect it
    function pause() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    function unpause() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // the key access logic
    function isDepositMintAllowed(address owner) public view virtual returns (bool) {
        return !paused() && ((depositMintAccess == accessType.open) || 
        ((depositMintAccess == accessType.allowList) && hasRole(DEPOSIT_ALLOWLIST, owner)) ||
        ((depositMintAccess == accessType.blockList) && !hasRole(DEPOSIT_BLOCKLIST, owner)));
    }

    function isWithdrawRedeemAllowed(address owner) public view virtual returns (bool) {
        return !paused() && ((withdrawRedeemAccess == accessType.open) || 
        ((withdrawRedeemAccess == accessType.allowList) && hasRole(WITHDRAW_ALLOWLIST, owner)) ||
        ((withdrawRedeemAccess == accessType.blockList) && !hasRole(WITHDRAW_BLOCKLIST, owner)));
    }

    function isTransferAllowed(address owner) public view virtual returns (bool) {
        return !paused() && ((transferAccess == accessType.open) || 
        ((transferAccess == accessType.allowList) && hasRole(TRANSFER_ALLOWLIST, owner)) ||
        ((transferAccess == accessType.blockList) && !hasRole(TRANSFER_BLOCKLIST, owner)));
    }

    // protection function used in other Suite contracts
    function requireManager() internal virtual override view {
        require(hasRole(MANAGER_ROLE, _msgSender()));
    }

    // useful modifiers
    modifier requireDepositMintAllowed (address owner) {
        require(isDepositMintAllowed(owner), "ERC4626Access: deposit or mint not allowed");
        _;
    }
    modifier requireWithdrawReedemAllowed (address owner) {
        require(isWithdrawRedeemAllowed(owner), "ERC4626Access: withdraw or redeem not allowed");
        _;
    }

    modifier requireTransferAllowed (address owner) {
        require(isTransferAllowed(owner), "ERC4626Access: transfer not allowed");
        _;
    }

    // helper functions (grantRole already enforces MANAGER_ROLE)
    function allowDepositMint(address investor) public virtual {
        require(depositMintAccess == accessType.allowList, "depositMintAccess is not allowList");
        grantRole(DEPOSIT_ALLOWLIST, investor);
    }
    function allowWithdrawRedeem(address investor) public virtual {
        require(withdrawRedeemAccess == accessType.allowList, "withdrawRedeemAccess is not allowList");
        grantRole(WITHDRAW_ALLOWLIST, investor);
    }
    function allowTransfer(address investor) public virtual {
        require(transferAccess == accessType.allowList, "transferAccess is not allowList");
        grantRole(TRANSFER_ALLOWLIST, investor);
    }
    function blockDepositMint(address investor) public virtual {
        require(depositMintAccess == accessType.blockList, "depositMintAccess is not blockList");
        grantRole(DEPOSIT_BLOCKLIST, investor);
    }
    function blockWithdrawRedeem(address investor) public virtual {
        require(depositMintAccess == accessType.blockList, "withdrawRedeemAccess is not blockList");
        grantRole(WITHDRAW_BLOCKLIST, investor);
    }
    function blockTransfer(address investor) public virtual {
        require(depositMintAccess == accessType.blockList, "transferAccess is not blockList");
        grantRole(TRANSFER_BLOCKLIST, investor);
    }

    // override max functions in ERC4626
    function maxDeposit(address owner) public view virtual override returns (uint256) {
        return isDepositMintAllowed(owner) ? super.maxDeposit(owner) : 0;
    }
    function maxMint(address owner) public view virtual override returns (uint256) {
        return isDepositMintAllowed(owner) ? super.maxRedeem(owner) : 0;
    }
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        return isWithdrawRedeemAllowed(owner) ? super.maxWithdraw(owner) : 0;
    }
    function maxRedeem(address owner) public view virtual override returns (uint256) {
        return isWithdrawRedeemAllowed(owner) ? super.maxRedeem(owner) : 0;
    }

    // _deposit() protects both deposit and mint, and is not usually overridden
    function _deposit (
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual override requireDepositMintAllowed(receiver) {
        super._deposit(caller, receiver, assets, shares);
    }

    // _withdraw protects both withdraw and redeem, and is not usually overridden
    function _withdraw (
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override requireWithdrawReedemAllowed(owner) {
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    // _transfer protects both transfer and transferFrom, and is not usually overriden
    // could also override _beforeTokenTransfer hook, but this seems cleaner
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override requireTransferAllowed(from) requireDepositMintAllowed(to) {
        super._transfer(from, to, amount);
    }
}
