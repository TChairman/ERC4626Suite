# ERC4626 Managed - contracts for standard portfolio management

Portfolios in the real world are managed by humans. These contracts are complete implementations of standard human-managed fund concepts in smart contracts, including investment, returns, fees, carry, and access control. See other directories for more sophisticated features like coupons and tranching.

# Overview

The [ERC4626](https://erc4626.info) spec provides a full-featured standard APi for investors, but it does not provide a complete implementation of a fund. In particular, it does not provide functionality for investing and returning funds. These contracts provide complete functionality for common fund types.

The Index Fund is the simplest vault type. Fund managers can accept LP funds and make discretionary investments into other ERC4626 vaults. The Managed vault allows for a wide variety of investment types, including off-chain investments. The Managed vault can easily be extended to allow for other types of investments, like loans.

All of these vaults build on the Fees and Access abstract contracts specified in the other directories, for features like access control, fees, and carry.

## ERC 4626 Index Fund

The Index Fund only allows investments in other ERC4626 vaults. Of course, the portfolio manager still has discretion regarding which vaults to invest in, so this is not secure against malicious portfolio managers. The manager also decides when to redeem investments and take gains.

To create an Index Fund, use the below factory, specify your fees and access constraints, and start investing!

## ERC 4626 Managed

Managed vaults allow different types of investments. The initial implementation enables both ERC4626 and off-chain investments. Portfolio managers doing off-chain investments have complete control of the assets they invest, and investors get very little transparency. Managers also manually specify when the investment value changes.

To create a Managed vault, use the below factory, specify your fees and access constraints, and start investing!

# Usage

These contracts offer complete implementations of a vault. As such, they can be used as-is, or of course they can be cloned and extended by developers. We provide factories for creating these vaults for convenience:

| Provider | ENS | Address | Status |
|---|---|---|---|
| Tom Shields | v1.indexfund.4626factory.eth | coming soon | Index Fund factory |
| Tom Shields | v1.managedfund.4626factory.eth | coming soon | Managed Fund factory |
