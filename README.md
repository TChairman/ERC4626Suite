# ERC4626 Suite

A full-featured and composable suite of vaults and extensions built on the [ERC4626](https://erc4626.info) standard.

## Vaults
* [Index Fund](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/managed) is a fund specifically for investing in other ERC4626 vaults under manager discretion.
* [Managed](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/managed) vaults include both ERC4626 and off-chain investments.
* [Debt Fund](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/managed) is a fund that pays coupons separately from investment gains.
* More coming soon!

## Extensions
* [Acccess controls](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/access) include local and global whitelists, integration with popular KYC standards, forced transfers and redemptions, and global enabling and disabling of deposits, withdraws, and transfers
* [Fee calculations](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/fees) include annual fees, withdraw fees, and carry on gains, as well as simple one-time expenses. Fees can be accrued and advanced.
* [Coupons](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/redemptions) are a way to pay interest and dividends without requiring redemption of underlying shares. This is important for debt funds, where interest is often paid periodically but withdrawals of principal may be restricted for the life fo the fund. Includes optional ability to push (airdrop) coupons directly to owner wallets.
* [Redemptions](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/redemptions) provide managers with the ability to create early liquidity, both for individual investors and the entire fund. While there are many ways that redemptions work, this extension provide the framework for managers to specify them and investors to claim them, giving the foundation that front ends can use to manage things like registering interest for redemptions and proportioning out redemption amounts.
* [Tranches](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/redemptions) allow managers to accept lower-risk capital higher on the stack. Tranches are protected by the equity first-loss capital, and generally pay a lower rate of return.
* [Deposit Escrow](https://github.com/tomshields/ERC4626Suite/tree/main/contracts/redemptions) allows managers to control the receipt of deposits, useful for closing a number of investors all at once. This is also the basis for Capital Calls.
* [Enumerability](https://github.com/tomshields/ERC4626Suite/tree/main/contracts) keeps an on-chain list of investor wallets, which ERC4626 does not have by default. This is important for things like coupon airdrops, or regulatory compliance.

NOT (YET) AUDITED. USE AT YOUR OWN RISK.

# Philosophy

Fund managers in the traditional finance world generally enjoy a great deal of autonomy and trust from their investors, backed by a robust legal system. DeFi promises to change all that, replacing the legal system and the trust with smart contracts. This has been very successful in a few narrow areas of finance, but has not yet conquered the largest markets, such as credit underwriting and corporate finance. Smart contracts have a great deal to offer to fund managers in these areas, ranging from loan servicing to investor management and fundraising. However, they will need to be eased into the world of smart contracts with tools and capabilities that are familiar to them.

Specifically this means giving fund managers wide abilities to disburse funds and manage them. This is anathema to the trustless DeFi world, but necessary to open up to the larger world of corporate finance, at least in the beginning. This project is designed to enable fund managers to have the capabilities they need, assuming they are fully trusted, while creating a lot of value by giving investors and other stakeholders transparency and standard interfaces.

Another philosophical difference is treating coupons different from investment gains. The ERC4626 standard, and indeed most on-chain investment vaults, simply treat coupons as if they increase the share price of the underlying investment. However, many funds in the real world are in assets that pay a coupon separately, and indeed investors are sometimes confused when they can't receive their monthly coupon. This suite includes extensions to ERC4626 to handle coupons separately.

Some fund managers will want to open their funds to qualified investors, and the router-based access control architecture here is designed for that case, as well as the other common case of whitelisting specific investors. Access is generally focused on deposits and transfers, withdrawals are more commonly controlled by redemptions. Other access controls are provided mostly for completeness.

Finally, many existing tranching implementations try to treat the senior tranches just like the equity investors, only with slightly different priority, somewhat like a preferred stock. This implementation instead treats tranches like loans to the fund, which need to be paid back before the equity gets value. This is much more in line with how most structured credit funds work, and greatly simplifies the fund structure.

From an architectural point of view, the suite provides a constellation of capabilities designed to work separately or together to enable a wide variety of credit and equity funds.

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
