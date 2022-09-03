# ERC4626 Fees - enable fees on any ERC4626 vault

The [ERC4626](https://erc4626.info) spec provides a full-featured standard APi for investors, but it does not specify how to compute fees. Fees are a nice way for portfolio managers and protocols to get paid. Simply substitute one of these contracts for ERC4626, set the fees in the constructor, and *tada* you're charging fees.

# Overview

Withdrawal fees are nice because they reward long-term holders with lower overall fees while discouraging jumping in and out. Carry fees are nice because they align incentives and help managers capture upside. Annual fees are nice to cover recurring costs.

We do not support deposit fees (nobody likes them, investors "lose money" immediately) or investment fees (these implementations don't know anything about the underlying investments).

We also support the ability to take one-time fees (such as fund formation expenses), as well as advance fees against future accruals. Both of these features can be disabled in the constructor.

Fees can be accrued and drawn when needed, and even repaid (for example, in the case of an advance).

## ERC 4626 Fee

Real-world fund managers generally charge annual fees on assets under management, as well as a carry fee on gains. Often there are one-time expenses, such as annual meetings or fund formation expenses, that are borne by the investors as well. Fund managers will generally accrue fees, although they sometimes need an advance early in the fund's life to cover start-up costs. Withdraw fees are less common, but can also be implemented separately or together with the other fees.

ERC4626Fee supports all of these use cases, as well as separate protocol fees.

The solution maintains a per-account basis in order to compute carry on gains, as well as for the fee on assets under managemment. The AUM "annual" fee is accrued continuously, and accounted for in the assets under management. Carry fees and withdraw fees can only be computed on withdraw, and so are not considered when looking at the vault performance as a whole.

Protocol fees can be specified in ERC4626ProtocolConfig, and can also be annual, carry, or withdraw fees. They are sent directly to a treasury address.

Advanced features like discretionary fees and fee advancement can be disabled in the constructor.

# Usage

These contracts are drop-in replacements for a standard ERC4626 implementation, such as the one by [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC4626.sol). Replace this:

```solidity
contract MyVault is ERC4626 {
    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset) ERC20(_name, _symbol) {}
}
```
With this for full-featured fees:
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
To do the work of computing and managing fees, these contracts override some of the key functions in ERC4626, 
such as `withdraw()` and `redeem()`, so be careful if you are also overriding them.