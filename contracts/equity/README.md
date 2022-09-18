# ERC4626 Access - easily implement KYC on your vault

Investment managers need to control access to their vaults for many reasons, ranging from regulatory compliance to investment strategy.
This project extends the [ERC4626](https://erc4626.info/) standard to enable full control over deposits, withdrawals, and transfers in a drop-in composable fashion.

The router/allowlist architecture enables flexible and powerful management of even large numbers of investors. 
Use an existing router maintained by a KYC provider (see list below), or implement your own router to enforce your specific KYC restrictions (see examples).
allowlist and approve this router in your ERC4626 implementation and *tada*, you now enforce KYC.

NOT (YET) AUDITED. USE AT YOUR OWN RISK.

# Architecture

ERC4626 provides a standard interface for investing in vaults. However, many vaults require kYC or other restrictions on investors. Allowlists are a reasonable solution for
a small number of investors, but not easily reusable, and expensive for large groups. Many companies are working on solutions for scaling KYC using NFTs and other mechanisms. These companies can provide a single router that implements their restrictions, and investment managers can use that one contract to enable restrictions on any of their ERC4626 vaults. 

Call flow:
```
    Investor <=> ERC4626AccessRouter <=> ERC4626Access Vault
```

## ERC4626 Access Router

The Access Router simply checks the KYC (or other restrction) status of the caller for deposits, mints, and transfers, and if allowed, passes the call along to the underlying vault. The underlying vault need only add the router to the allowlist to enable all of the restricted users to access. 
The caller's address is the startng point for restrction evaluation; the router may use blockchain state (e.g. NFTs), oracles, or other mechanisms for validation.

The router maintains no state with respect to the underlying vaults, although it may retain state about its restrictions (e.g. a allowlist of its own). 

More than one router can be allowlisted, in that case frontends should understand which router needs to be called for a given wallet. The router also provides a public view function isAllowed() to check restrictions before wasting gas on a transaction. The underlying vault should max allow the router.

## ERC4626 Access

ERC4626Access is a drop-in replacement for ERC4626 that implements separate allowlists or blocklists for deposits, withdrawals, and transfers. Managers can also set deposits, withdrawals, or transfers as globally open or globally prevented. Since it inherits from Pausable, it also allows pausing as well.

The implementation can allow or block any address for any of the mutable functions, and does not care what other EOAs, contracts, or routers are also allowlisted. Here's an example of allowing a router:

```solidity
allowDepositMint(<ROUTER_ADDRESS>);
```

Any frontends may need to be adjusted to call the router for deposits, mints, and transfers. Withdrawals can also go through the router, but are not generally restricted - if they hold your token, presumably they already passed the restrictions.

## ERC4626 Force

Many jurisdictions require the ability to force the transfer or redemption of shares, for a variety of reasons. This extension gives the manager the ability to force transfer or force redeem individual investors. Most likely used in conjunction with [ERC4626Enumerable](https://github.com/tomshields/ERC4626Suite/tree/main/contracts) to keep track of the investors. 

# Known Routers

| Provider | ENS | Address | Status |
|---|---|---|---|
| Tom Shields | tomfriends.4626access.eth | coming soon | Friends of Tom allowlist |
| [Goldfinch US Accredited](https://docs.goldfinch.finance/goldfinch/unique-identity-uid/for-developers) | goldfinchUID1.4626access.eth | coming soon | unaffiliated with Goldfinch

# Access Router Implementation

KYC and other identity providers should create and maintain their own routers which can be used by any ERC4626 vault provider. 
For convenience, we have reserved `4626access.eth` as a domain for these, contact us if you'd like to reserve a subdomain for your permanent router.

Creating a new router is fairly easy. Implement `isAllowed()` with your restrictions (e.g. check an NFT, etc). Then instantiate the contract and deploy. See the example code in test, or the related `GlobalAllowlistERC4626Router`.

## Primary Functions Provided

```solidity
isAllowed(address to) returns bool;
deposit(IERC4626 vault, address to, uint256 amount) returns (uint256 shares)
mint(IERC4626 vault, address to, uint256 shares) returns (uint256 amount)
safeTransfer(ERC20 vault, address to, uint256 amount);
safeTransferFrom(ERC20 vault, address from, address to, uint256 amount);
```
