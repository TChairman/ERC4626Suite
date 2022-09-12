// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "../ERC4626SuiteContext.sol"; 

/// @notice Hold deposits for eventual acceptance by the manager. Foundation of Capital Calls, but useful for
/// @notice other things like multiple closings as well.
/// @notice From the user perspective, when they deposit() they get 0 shares. When the deposit is accepted or rejected by the manager,
/// @notice the shares are airdropped to the "to" address, and any remaining assets are airdropped back where they came from. Deposits can
/// @notice also be reclaimed before the manager accepts them.
/// @notice maxMint returns 0, and as a result calls to mint() will revert, as the share price may change between deposit and acceptance.

abstract contract ERC46266DepositEscrow is ERC4626SuiteContext {
    using Math for uint256;

    uint32 constant MAX_ESCROWED_DEPOSITS = type(uint32).max;

    // Variables
    uint256 public totalDepositsEscrowed;
    struct depositType {
        address caller;
        address receiver;
        uint256 assets;
    }
    depositType[] public _deposits;
    mapping (address => uint32) public _depositIndex;

    // Events
    event depositEscrowedEvent (address owner, address receiver, uint256 assets);
    event depositReturnedEvent (address owner, uint256 amount);

    constructor() {
        _deposits.push(depositType(address(0), address(0), 0)); // guard entry in deposits array
    }

    function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
        require(assets <= maxDeposit(receiver), "ERC4626: deposit more than max");
        address sender = _msgSender();
        require(IERC20(asset()).transferFrom(sender, address(this), assets), "deposit: transfer failed");
        uint32 index = _depositIndex[sender];
        if (index == 0) {
            require(_deposits.length <= MAX_ESCROWED_DEPOSITS, "deposit: exceeded max escrowed deposits");
            _depositIndex[sender] = uint32(_deposits.length);
            _deposits.push(depositType(sender, receiver, assets));
        } else {
            _deposits[index].assets += assets;
            _deposits[index].receiver = receiver; // can't have separate receivers for multiple deposits, use most recent one
        }
        totalDepositsEscrowed += assets;
        emit depositEscrowedEvent(sender, receiver, assets);
        return 0;
    }

    // share price may change between deposit and acceptance, so disable minting
    function maxMint(address) public view virtual override returns (uint256) {
        return 0;
    }

    function escrowedBalanceOf(address owner) public virtual view returns (uint256) {
        return _deposits[_depositIndex[owner]].assets;
    }

    function reclaimEscrowedDeposit(uint256 amount) public virtual {
        _returnDeposit(_msgSender(), amount);
    }

    function returnEscrowedDeposit(address owner, uint256 amount) public virtual onlyManager {
        _returnDeposit(owner, amount);
    }

    function _returnDeposit(address owner, uint256 amount) internal virtual {
        uint32 index = _depositIndex[owner];
        require(index > 0, "returnDeposit: owner not found");
        if (amount > _deposits[index].assets) amount = _deposits[index].assets;
        require(IERC20(asset()).transfer(owner, amount), "returnDeposit: transfer failed");
        _deposits[index].assets -= amount;
        totalDepositsEscrowed -= amount;
        emit depositReturnedEvent(owner, amount);
    }

    function returnAllEscrowedDeposits () public virtual onlyManager {
        for (uint32 i = 0; i<_deposits.length; i++) {
            require(IERC20(asset()).transfer(_deposits[i].caller, _deposits[i].assets), "returnAllEscrowedDeposits: transfer failed");
            emit depositReturnedEvent(_deposits[i].caller, _deposits[i].assets);
        }
        totalDepositsEscrowed = 0;
        delete _deposits; // might as well clean it up
        _deposits.push(depositType(address(0), address(0), 0)); // guard entry in deposits array
    }

    function acceptEscrowedDeposit(address sender, uint256 amount) public virtual onlyManager returns (uint256) {
        uint32 index = _depositIndex[sender];
        require (index > 0, "acceptDeposit: sender not found");
        require(amount <= _deposits[index].assets, "acceptDeposit: not enough escrowed assets");

        uint256 shares = previewDeposit(amount);
        _mint(_deposits[index].receiver, shares);

        _deposits[index].assets -= amount;
        totalDepositsEscrowed -= amount;

        emit Deposit(_deposits[index].caller, _deposits[index].receiver, amount, shares);
        return shares;
    }

    // use this in totalAssets() instead of asset.balanceOf(this)
    function availableAssets() public virtual override view returns (uint256 avail) {
        avail = super.availableAssets();
        assert(avail >= totalDepositsEscrowed); // should never get here
        unchecked {
            avail -= totalDepositsEscrowed;
        }
    }

}
