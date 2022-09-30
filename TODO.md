Projects:
Rewrite Fee, simplify and separate Carry/basis calcs
Fund types - both for test and for real (see below)
GitBook Documentation, including order of inclusion diagram
Tests
Organize functions within files around manager, investor, lender, helper
Do EIP165 identification
Linting and pretty-printing
Gas optimization
Varaible and function naming rationalization
In-code documentation
Enable contract cloning
Deploy basic factories to .ETH addresses
Make interfaces for everything
Go back to original spec for investment abstract

Smaller todos:
Check interaction of fees and redemptions
Carry fees likely must be able to override redemptions - fees maybe should always come last in the list?
Check handling of declining asset value on coupon repayments to senior tranches
AutoAcceptEquityDeposits = true; Also enable for individual investors?
Can tranche owner (vault) update to new owner?
Allow coupon updating and withdrawing "as of" date, to get periods more exact
Closing fund = issue redemption(max), potentially push coupons and force redeem if enumerable
Add function to credit received funds - basically if balance changes unexpectedly, manager can retroactively credit the pushed funds to an asset, otheriwse equity value will briefly pop up - could present an issue if withdrawals are turned on, so maybe eventually keep track of expected asset balanceOf. Hmm.
Detect if whitelist address is contract and if so set allowance to max: _token.safeApprove(address(_pool), type(uint256).max);
Fix transfer allowlist to handle pairs
Create reserve fund
Idea: revive failsafe timer for vaults in Access
On fees test how much they diverge over time from the actual fee bps 
Might need accruedCarry to handle premature carry paid
Do the Maple thing, coupon vests over the period to smooth things out
Repay could specify date as of for compute and setting last, and if zero means block time stamp - use to make periods match nicely 
Change access to use triggers and not override 
Hurdle rate for carry on equity 
Auto reinvest coupons.
Add LP controls into capital calls. LP can choose pull or push, auto reinvest
Add an offer premium as counterpart to redemption penalty

Fees rewriting:
_basis handling in redemptions, transfers
Fix totalPaidIn in transfer in Fees.sol
make them liabilities
Probably resuscitate withdraw fees as a basic fee
PaidInCapitalFee - do with carry
AUMFee
CouponFee
CarryFee
WithdrawFee?
DepositFee?
Transfer fee?
Fee base for accrue fee etc
Basis just to keep track
Carry works off basis not investments
Withdraw fee
Aum fee taken on most manager txs - compute on basis or asset value? Need to update when basis or asset Val changes 
Coupon fee on distribute 
Redemptions don’t support withdraw and carry fees yet
Redo carry when tranching is figured out 

Presets list:
MockAccess is Access - test whitelists and enable/disable transactions
MockFees is Fees - test fees
IndexFund is 4626 and OffChain investments, Fees, and Access
ManagedFund is Index Fund + Redemption (includes FeesAccess) - enable fine-grained withdraw controls
MockRedemption is Redemption - redemptions with no fees or access control
DebtFund is Coupon, Fees, and Access) - enable payment of coupons/dividends, coupon fees to treasury
MockCoupon is CouponPush, Access - coupon logic without fees
DebtRedemptionFund is Coupon, Redemption, Fees, Access
StructuredFund is Tranche, Fee, Access
StructuredRedemptionFund is TranchedRedemption
StructuredDebtFund is TranchedCouponRedemption
VentureFund is CapitaCall, Redemption - enables accounting for funds not yet called, and accounts for those deposits separately
VentureDebtFund is CouponRedemption, CapitalCall
TrancheFund with fees
Flexible portfolio

Need philosophy on:
When amounts should be reduced to max vs when it should revert - fill or kill
Pull vs push
Reserved assets
Multi-Vault and debt-vault
Assets - Liabilities = Equity
Event naming and frequency - every mutable transaction?
Allowing non-owners to deposit - subject to some sort of griefing?
Should withdraw(0) revert or just transfer 0?
par value vs net asset value concept for both equity and debt

From the book:
Asset based fees, plus debt fee for each Tranche, paid first
Withdraw fee is maybe just a one-time debt fee? Can model as an assumption. Probably diff for each tranche.
Tranches have fixed rate interest for now, but could have floating rate based on an oracle or something. Share in upside?
Sequential vs pro-rata principal payment for tranches - probably should support both
For sequential: Principal due is scheduled amortization, voluntary payments, plus new defaults. Excess spread can help cover any shortfalls
When assets go down, liabilities have to go down

Documentation:

Redemptions vs withdraw control:
Access control allows open withdrawals, disabled withdrawals, or a withdrawal whitelist. In the open case and the whitelist cases, a withdrawal race can occur if some assets are still not liquid. In addition, withdrawals can stymie planned invesmtments if assets are removed before the investment can be made. Redemptions solve this problem. The manager can specify redemptions on an individual LP basis, or globally for all LPs.

Reserved assets: deposits not yet accepted, redemptions not yet claimed, and coupons not yet claimed (if not pushed)

Example: equity funds $20m of loans, then sr tranches comes in and "buys" $15m, equity can redeem $15m assets for something else
Can always add another tranche between equity and lowest tranche

thinking might want the loan contract to be the "servicer" and have the borrower not really care who the "owner" is of the loan, just call the servicer to repay
then the servicer in the same tx calls the owner and repays there, so the servicer contract does not retain any funds
this lets servicer do any complex computatation or maintenance of amortization schedules, while owner just gets funds and updates on interest, principal and remaining value

Funds can get funds from equity investors and from loans. Senior tranches are functionally the same as loans to the portfolio.
Funds can invest in equity investments that are expected to increase in value, or in loans that pay a coupon
Funds take fees, manage idle capital, and may keep a required reserve
Have ERC4626 for the equity party. Need a standard or proposed standard API for the debt side of things.
Current plan: just add withdrawCoupon. Redemptions/amortization can come from redeem(maxRedeem())

Naive policy: withdraw can take whatever idle funds are available at the current share value - almost never the right answer until the end of the fund
Solutions to the "withdraw race" problem:
Liquid Exit: charge higher withdraw fees as idle funds get smaller as a % of total assets
Redemptions: Manager designates a portion of assets for withdrawal, investors can only withdraw their share
No withdrawals at all until end of fund
Any others?
Closing fund = issue redemption(max)

OffChain:
Manager decides to make an investment, takes funds, deploys them
Manager may update the expected return and/or NAV periodically to accept additonal deposits, mark to market, or issue redemptions
Manager may sweep and distribute coupons and/or redemptions
At some point the investment matures or reaches an outcome, manager re-deposits funds and closes the position

ERC4626 Vault: same as offchain except NAV is looked up when updated. Expected return can still be set if desired.

Think about actual manager flow here:
Create a fund
Deposit some initial capital
Make or buy an investment
Create & connect senior tranche
Accept a senior tranche loan
Make some more investments
Check to see that coupons are all paid
Run the waterfall every month or week
Decide to redeem an equity investment
A loan matures and gets paid back
Sell a loan or equity investment
Accept a secondary closing
Issue a partial redemption
Draw a fee
Close the fund


ERC4626 is the foundation of investor management. The standard allows simple deposits and redemptions, and opens funds up to new sources of capital. This suite offers extensions to the investor management functionality to enable real-world requirements like access control, managed deposits and redemptions, fees, and regulatory compliance.

Fund managers also need to package and structure assets into funds. The Funds section of this suite offers a standard way to keep track of assets in the fund, accept tranches for funding, and manage the waterfall.

Missing from this suite are tools to help with asset origination and servicing. Credit modeling and underwriting, and net asset value computation, currently happen off chain. Other protocols handle servicing, for example managing borrower repayments on individual loans. This suite provides a standard and simple way to represent such investments, maintain their values, and manage payouts.

The point is: run the waterfall including logic and value transfer. Handle deposits and redemptions easily and properly, in a way that opens up to new sources of capital. Not origination or servicing, really, yet.

Push vs pull pattern:
ERC4626, and most vaults, follow the standard pull pattern. However, for recurring payments like monthly coupons, this reduces user experience.
How does Goldfinch do this? Looks like they have a periodic pull script...

Create an equity fund, with asset, strategy, and fees
Create a tranche or tranches on the equity fund
Create tranche funds (or add to existing tranche funds, but not recommended)
In the equity fund, make the owner of the tranche the newly created tranche fund
In the tranche fund, create the tranche asset pointing at the equity fund
Begin accepting deposits to both tranche fund and equity fund
Tranche fund deposits into equity fund tranche
Equity fund accepts tranche deposits, starts clock on returns
Equity fund makes investments, starts running waterfall
Tranche fund periodically pulls coupons
Equity fund repays tranche fund principal
Tranche fund pulls principal and returns to its investors

Here it is: tranched fund is multi-Vault. VaultID 0 = equity tranche. Multi-vault investor can invest in any multi-vault, including a tranched fund
In-between multi portfolio where it's only one currency and set of assets, but different risk/returns - this is tranches
Basically use part of the API, but simplify to tranches
Remember NAV is different from par value (principal due). Par value is shares balanceOf, maybe? NAV is previewRedeem?

ERC 4626 Multi:
Lots of folks (find references) have talked about multi-vaults and potential extensions to the standard. Would be great to standardize at some point, but following the lead of OpenZeppelin, might be just an accepted methodology instead of a standard.
Add uint256 vaultID to every standard call in ERC4626. Also steal balanceOf and transfer from ERC1155. Use uint256 because it can encode lots of things: a simple ID, a byyes32 string identifier, an address of a token, or even a hash of a token and an ID for multiple vaults with the same underlying asset.
Here's an implementation, here's mine (see tranches).

ERC 4626 Debt:
How to adapt ERC4626 to represent a loan or set of loans:
deposit() and mint() do the same thing, shares are always equal to principal remaining to be repaid in assets
balanceOf() gives you the principal remaining (par value if it's a bond or bullet loan)
if the fund does a NAV calculation, then you can get NAV as separate from principal due by checking previewRedeem(balanceOf())
maxWithdraw will tell you how much principal you can collect, use withdraw() to get it
to collect coupon payments, use withdrawCoupon and maxWithdrawCoupon
To collect amortization payments of principal, use withdraw or redeem - they will do the same thing unless the loan is underperforming
If the loan/portfolio is underperforming - shares are 1-1 for assets, until they are zero. Redemptions of remaining shares likely just ignored or burned.
If there is extra value from the loan somehow (warrants, or something) - send it as extra coupon, maybe at the end or whenever
If you don't care about coupon vs principal, maybe there's a wrapper to combine them? Hmm. Make coupons redemptions with 0 shares? Have another mechanism for determining how much was coupon and how much was principal? Maybe shares redeemed are principal, rest is coupon?
maybe redeem() just collects principal, where withdraw() collects coupon first (0 shares) and then principal if avail? Hmm. maxWithdraw gives sum, maxRedeem is just principal
Actually there's principal, there's distribuitons waiting, and there's coupons waiting. I guess:
balanceOf(this) = remaining principal + waiting escrow (distribution or not accepted deposit)
maxWithdraw(this) = distribution + coupon, returns distribution amount
maxRedeem(this) = distribution, returns distribution amount
maxDeposit checks for max debt size
maxMint = maxDeposit
deposit() fails if it will exceed max debt size, may deposit to escrow
mint() = deposit()
all preview and convert functions just return 1-1
Make ERC4626 work for loans? Seems a bit janky, but could redeem(0) to get coupon, or always redeem(maxredeem()) to get whatever coupon + amortization is available
Maybe have shares always = principal assets
If default, then shares just can’t be redeemed
If increase in value, then what? Maybe maxwithdraw can capture excess amortization?

Is this just rebasing? Hmm.

Why ERC4626 doesn't work well for loans or baskets of loans:
Usually deposit() happens once, although sometimes loan balance is increased in a renegotiation
mint() is the same as deposit, share price never changes so previewMint and previewDeposit are just 1-1

Coupons accrue continuously in tranches
Coupons come in randomly from investments
Coupons that come in are held until manager calls waterfallCoupon at the end of the week/month to distribute coupons to tranches/equity
Tranche funds can then withdraw escrowed coupon funds
Can tranche funds discover accrued but not yet waterfalled coupons? Might want a public function for that
Functions to get expectedReturnBPS, NAV, etc?

All of our vaults take a 5bps fee for use of the contracts and software, this is paid to a treasury wallet. Of course you can always fork the code and reduce or remove this if it is a barrier to your use.

Fund instead of vault? Or spv?
More thinking about actual use cases and the step by step adoption curve
Maybe just a SPV vehicle to start?

1 contract for all funds for a KYC regime, e.g. one ERC4626GoldFinchRouter, based on ERC4626Router
One Factory to create funds and tranches, might as well also keep track of them, and implement the multi call router from solmate

Deposit restrictions are about participation. Withdrawal restrictions are about liquidity. Hmm. 
Focus on capabilities, not restrictions. Want fund managers to be able to do what they need, can add restrictions later.

Thinking a lot about generic investments. Investments should have a current value, last value date, annual expected change in value, and an address. Explore the question of can we store an ABI encoded address to call for updating the value. Maybe we need to store a investment type. 

One-time fees subtracted immediately from totalEquity, taken into account when recorded, implies potential step-function changes in value
Annual fees continuously subtracted from totalEquity, so always taken into account
Carry fees are taken when funds are withdrawn (not taken into account until withdraw) or distributed via redemptions (taken into account with preview, max, and withdraw, but not convert)
Withdraw fees are taken when funds are withdrawn or distributed via redemptions (same as carry)
Coupon fees are taken when coupon paid

Another idea: selling assets (loans, or investments) atomically, so NAV doesn’t swing wildly, even for a second
Cool workaround: trade other asset for OffChain asset of correct value, then redeem that for cash or even trade for another investment

Diagram:
Manager
Investors
Assets
Liabilities
Fees

Spreadsheet for testing:
Event number and days since last
Description of asset
Coupon, redemption, remaining value, gain or loss
Investment is neg redemption

On fund creation:
Set deposit allowlist
 - collect some deposits in warehouse
Create tranches
 - collect some deposits in warehouse
Create investments
 - off chain, easy
 - ERC4626 or other equity investments, fairly easy
    - manager decides when to withdraw and how much
 - Loans or other debt investments, harder
    - take their ID and hash it to find investment index
    - assume they manage the servicing and the breakdown of interest vs amortization and remaining value, we pull the assets
Accept deposits, and accept tranches
Fund investments

Can continue to accept deposits and tranches and create and fund new investments early in fund’s life
Can recycle redemptions for new investments

Monthly: 
Take fees
pay tranches
Update asset values
Issue coupons to equity if available
  - extra credit: ability to share % of excess coupon with tranches
Do any equity investments or redemptions

As fund and debt assets mature:
Pay down tranches with amortization
  - how to figure out when to do this? Just based on total debt investments?
Redeem remaining equity investments
Start redemptions for equity holders, take carry
  - extra credit: share % of upside with tranches
Close the fund

Tranche Fund:
Set deposit restrictions
Create one tranche (debt) asset
Link to tranche of underlying

Investor Alice puts $150k and Bob puts another $50k into an ERC4626 vault. The manager invests in a portfolio of two $100k loans. One is at 5% interest only maturing in 3 months. The other is fully amortizing at 4% over 6 months. The fund is closed-ended at 6 months and does not recycle. Alice and Bob would like to get a monthly coupon, and then redeem their principal when the loans mature.

With “standard” ERC4626, the loan interest is added to the total assets when it is paid, and then Alice and Bob can withdraw at the new share/asset price. However, without a separate accounting system, Bob can withdraw more than just share of interest and principal, leaving Alice unable to collect. So a separate accounting system for the interest and amortizatization is needed in any case. 

In addition, the separate loan maturity dates, and the amortization schedule, means that 

Given that, it is much simpler and more readable for the vault share value to remain reflective of the principal value, and not the expected total paid out value. Any principal losses are reflected in the loan value, but interest is accounted for separately. Thus the motivation for this add-on standard.

ERC4626Debt

The ERC4626 standard has hit a nice sweet spot between simple enough to understand and complete enough to solve a real problem. Seems like there are a fair number of projects, both public and private, that are adopting the standard. Now, as with ERC20, a number of optional enhancements can be proposed. 

For example, some funds throw off coupons or dividends. These are not easily represented by the ERC4626 standard, as they are generally thought of as different from the “core” investment. Stock dividends, for example, are generally pushed to the end investors, and must be actively re-invested. Coupons from debt instruments are likewise generally pushed, and not accrued in a fund that has no way to reinvest them. Even if the coupon or dividend were to be simply added to the ERC4626 vault asset value, there would have to be mechanisms to prevent one investor from redeeming their entire investment from the coupon, leaving other investors with no liquidity.

The ERC4626Debt spec proposes to solve these issues. 

While this standard enables an ERC4626Coupon vault to represent a single loan, it’s likely overkill for that use case, and one of the many NFT implementations is likely more efficient. The intent is for an ERC4626Coupon vault to be able to represent a debt fund that is composed of multiple loans, or an equity and debt fund that has a combination of both.

Issue one redemption for x shares and 0 assets is almost the same as force redeem, just doesn't push the assets.

As an investment manager you don’t want a protocol that’s never had a default. 

Deposits can be wide open; specific investors, or specific kyc or accredited lists
Funds can be instant deposit, escrow deposit, and capital calls
Withdrawals can also be enabled or disabled globally or for specific investors. Exit can be liquid (maybe with a penalty) or a redemption or a coupon
Transfers can be prevented or allowed. Redemptions and coupons already issued are not transferable. 
Getting value of investment is convert to assets , not max withdraw
Use carry fee structure to share upside with tranches too - basically carry for tranches 
Basis -> carry -> tranche carry

Draw picture of inheritance diagram and order of inclusion with overridden functions

Thesis: most of the interactions between fund managers and their investors, or between fund managers and their investments, are super nuanced and not easy to capture in code. This implies they SHOULD NOT (and in many cases CAN NOT) be enforced on-chain. For example, defaults and loan renegotiations are very complex, and managers need full discretion to make creative solutions, the blockchain just gets in the way.
So why use smart contracts at all? To handle the 80% case of everything goes well. To provide transparency on all the fund flows. And to open up to a wider universe of investors.

Redemptions override withdraw fees (including protocol withdraw fees) but do have an optional redemption fee. 
