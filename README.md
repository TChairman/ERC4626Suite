# ERC4626 Suite

A full-featured and composable suite of vaults and extensions built on the [ERC4626](https://erc4626.info) standard.

## Vaults
* [Index Fund](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/managed) is a fund specifically for investing in other ERC4626 vaults under manager discretion.
* [Managed](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/managed) vaults include both ERC4626 and off-chain investments.
* [Debt Fund](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/managed) is a fund that pays coupons separately from investment gains.
* More (including tranches) coming soon!

## Extensions
* [Acccess controls](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/access) include local and global whitelists, integration with popular KYC standards, and global enabling and disabling of deposits, withdraws, and transfers
* [Fee calculations](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/fees) include annual fees, withdraw fees, and carry on gains, as well as simple one-time expenses. Fees can be accrued and advanced.
* [Coupons](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/redemptions) are a way to pay interest and dividends without requiring redemption of underlying shares. This is important for debt funds, where interest is often paid periodically but withdrawals of principal are restricted for the life fo the fund. Includes optional ability to push (airdrop) coupons directly to onwer wallets.
* [Redemptions](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/redemptions) provide managers with the ability to create early liquidity, both for individual investors and the entire fund. While there are many ways that redemptions work, this extension provide the framework for managers to specify them and investors to claim them, giving the foundation that front ends can use to manage things like registering interest for redemptions and proportioning out redemption amounts.
* [Enumerability](https://github.com/tomshields/ERC4626Suite/tree/main/contracts) keeps an on-chain list of investor wallets, which ERC4626 does not have by default. This is important for things like coupon aidrops, or reglatory compliance.

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
