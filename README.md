# ERC4626 Suite

A full-featured and composable suite of extensions built on the [ERC4626](https://erc4626.info) standard.
* [Acccess controls]() include local and global whitelists, integration with popular KYC standards, and global enabling and disabling of deposits, withdraws, and transfers
* [Fee calculations]() include annual fees, withdraw fees, and carry on gains, as well as simple one-time expenses. Fees can be accrued and advanced.

NOT (YET) AUDITED. USE AT YOUR OWN RISK.

# Overview

Most of these contracts are drop-in replacements for a standard ERC4626 implementation, such as the one by [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC4626.sol). For example, this may be your vault today:

```solidity
contract MyVault is ERC4626 {
    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset) ERC20(_name, _symbol) {}
}
```
You can enable basic fees simply by replacing it with this:
```solidity
contract MyVault is ERC4626BasicFee {
    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _managerTreasury,
        uint32 _managerFeeBPS
    ) ERC4626(_asset) ERC20(_name, _symbol) ERC4626BasicFee(_managerTreasury, _managerFeeBPS) {}
}
```
Voila! You are now charging a fee. More details on implementation are in each contract directory.

# Usage

### Prerequisites

Before running any command, make sure to install dependencies:

```sh
$ npx hardhat
$ npm install @openzeppelin/contracts
```

### Compile

Compile the smart contracts with Hardhat:

```sh
$ npx hardhat compile
```

### Test

Run the tests:

```sh
$ npx hardhat test
```

### Deploy contract to network (requires private key and Alchemy API key)

```
npx hardhat run --network goerli ./scripts/deploy.ts
```

### Validate a contract with etherscan (requires API key)

```
npx hardhat verify --network <network> <DEPLOYED_CONTRACT_ADDRESS>
```
