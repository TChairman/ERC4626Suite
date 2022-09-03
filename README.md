# ERC4626 Suite

A full-featured and composable suite of vaults and extensions built on the [ERC4626](https://erc4626.info) standard.

## Vaults
* [Managed](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/managed) vaults are complete implementations of standard human-managed fund concepts in smart contracts, including investment, returns, fees, carry, and access control.
* More (including coupons and tranches) coming soon!

## Extensions
* [Acccess controls](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/access) include local and global whitelists, integration with popular KYC standards, and global enabling and disabling of deposits, withdraws, and transfers
* [Fee calculations](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/fees) include annual fees, withdraw fees, and carry on gains, as well as simple one-time expenses. Fees can be accrued and advanced.
* [Coupons](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/redemptions) are a way to pay interest and dividends without requiring redemption of underlying shares. This is important for debt funds, where interest is often paid periodically but withdrawals of principal are restricted for the life fo the fund.
* [Redemptions](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/redemptions) provide managers with the ability to create early liquidity, both for individual investors and the entire fund. While there are many ways that redemptions work, this extension provide the framework for allowing them, assuming that front ends will manage things like registering interest for redemptions and proportioning out redemption amounts.

NOT (YET) AUDITED. USE AT YOUR OWN RISK.

# Overview

The complete vaults can be instantiated with factories and used immediately. See the individual directories for details.

Tne extension contracts are drop-in replacements for a standard ERC4626 implementation, such as the one by [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC4626.sol). For example, this may be your vault today:

```solidity
contract MyVault is ERC4626 {
    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset) ERC20(_name, _symbol) {}
}
```
You can enable fees simply by replacing it with this:
```solidity
contract MyVault is ERC4626Fee {
    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        uint32 _annualFeeBPS,
        uint32 _carryFeeBPS,
        uint32 _withdrawFeeBPS,
    ) ERC4626(_asset) ERC20(_name, _symbol) 
      ERC4626Fee(_annualFeeBPS, _carryFeeBPS, _withdrawFeeBPS, false, false) {}
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
