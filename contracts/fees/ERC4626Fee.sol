// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "../access/ERC4626BasicAccess.sol";

/// @notice ERC4626 tokenized Vault implementation with annual, carry, and withdraw fees
/// @notice Derived from ERC4626BasicAccess to allow for fee accrual and management
/// @notice based on OpenZeppelin v4.7 (token/ERC20/extensions/ERC4626.sol)

// TODO consider making this clonable and therefore initializable
// When using Fee contracts as a base, make sure your totalAssets implementation uses availableAssets() instead of balanceOf(this) to account for accrued fees
// Test to make sure this works when fee accrual exceeds free token balance, this may be common


abstract contract ERC4626Fee is ERC4626BasicAccess {
    using Math for uint256;

    uint32 constant BPS_MULTIPLE = 10000;
    uint32 public immutable annualFeeBPS;
    uint32 public immutable carryFeeBPS;
    uint32 public immutable withdrawFeeBPS;
    bool public immutable disableDicretionaryFee;
    bool public immutable disableFeeAdvance;
    mapping (address => uint256) private _basis;
    uint256 public totalBasis;
    int256 public accruedFees; // may be negative if fee advances are made
    uint256 lastAnnualFeeAccrual;

    constructor(uint32 _annualFeeBPS, uint32 _carryFeeBPS, uint32 _withdrawFeeBPS, bool _disableDiscretionaryFee, bool _disableFeeAdvance) {
        require(_annualFeeBPS < 10000, "Annual Fee must be less than 100%");
        annualFeeBPS = _annualFeeBPS;
        require(_carryFeeBPS < 10000, "Carry Fee must be less than 100%");
        carryFeeBPS = _carryFeeBPS;
        require(_withdrawFeeBPS < 10000, "Withdraw Fee must be less than 100%");
        withdrawFeeBPS = _withdrawFeeBPS;
        disableDicretionaryFee = _disableDiscretionaryFee;
        disableFeeAdvance = _disableFeeAdvance;
    }

    // use this in totalAssets() instead of asset.balanceOf(this)
    function availableAssets() public virtual view returns (int256 avail) {
        avail = toInt256(IERC20(asset()).balanceOf(address(this))) - accruedFees - toInt256(accruedAnnualFee());
    }

    function accrueFee(int256 fee) internal virtual {
        accruedFees += fee;
    }

    function accruedAnnualFee() public virtual view returns (uint256) {
        return totalBasis.mulDiv(annualFeeBPS, BPS_MULTIPLE, Math.Rounding.Up).mulDiv(block.timestamp - lastAnnualFeeAccrual, 365 days);
    }

    // do this every time totalBasis is updated, e.g. in deposit and withdraw
    function updateAnnualFee() public virtual {
        accrueFee(toInt256(accruedAnnualFee()));
        lastAnnualFeeAccrual = block.timestamp;
    }

    function updateTotalBasis(int256 change) internal virtual {
        updateAnnualFee();
        if (change < 0) { // protect the casts to uint
            require(uint256(-change) <= totalBasis, "totalBasis can't go negative");
            totalBasis -= uint256(-change);
        } else {
            totalBasis += uint256(change);
        }
    }

    // Functions overridden from ERC4626

    // uses owner and includes carry fees
    function maxWithdraw(address owner)
        public
        view
        virtual
        override
        returns (uint256 assets)
    {
        (assets, ) = _convertToAssetsOwner(balanceOf(owner), owner);
    }

    /** @dev See {IERC4626-withdraw}. */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(assets <= maxWithdraw(owner), "ERC4626: withdraw more than max");

        (uint256 shares, int256 feeAmount) = _convertToSharesOwner(assets, owner);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
        accrueFee(feeAmount);

        return shares;
    }

    /** @dev See {IERC4626-redeem}. */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");

        (uint256 assets, int256 feeAmount) = _convertToAssetsOwner(shares, owner);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
        accrueFee(feeAmount);

        return assets;
    }

    function netAssets(address owner) public virtual view returns (uint256 assets, uint256 fees) {
        uint256 totalSup = totalSupply();
        if (totalSup == 0) return (0,0);
        assets = balanceOf(owner).mulDiv(totalAssets(), totalSup); // what owner would have with only annual fees accrued
        fees = 0;

        // calculate carry fee
        if (carryFeeBPS > 0) {
            int256 gainLoss = toInt256(assets) - toInt256(_basis[owner]);
            if (gainLoss > 0) { // unsafe cast below is okay because we check for > 0 here
                fees += uint256(gainLoss).mulDiv(carryFeeBPS, BPS_MULTIPLE, Math.Rounding.Up);
                assets -= fees;
            }
        }

        // calculate withdraw fee
        if (withdrawFeeBPS > 0) {
            uint256 wFee = assets.mulDiv(withdrawFeeBPS, BPS_MULTIPLE, Math.Rounding.Up);
            fees += wFee;
            assets -= wFee;
        }
    }

    function _convertToSharesOwner(uint256 assets, address owner) internal view virtual returns (uint256 shares, int256 fees) {
        (uint256 netAss, uint256 netFee) = netAssets(owner);
        shares = balanceOf(owner).mulDiv(assets, netAss, Math.Rounding.Up);
        fees = toInt256(netFee.mulDiv(assets, netAss, Math.Rounding.Up));
    }

    function _convertToAssetsOwner(uint256 shares, address owner) internal view virtual returns (uint256 assets, int256 fees) {
        (uint256 netAss, uint256 netFee) = netAssets(owner);
        assets = netAss.mulDiv(shares, balanceOf(owner), Math.Rounding.Up);
        fees = toInt256(netFee.mulDiv(shares, balanceOf(owner), Math.Rounding.Up));
    }

     /**
     * @dev Internal conversion function (from assets to shares) with support for rounding direction.
     * Copied from OpenZeppelin and updated to include withdraw fee.
     *
     * Will revert if assets > 0, totalSupply > 0 and totalAssets = 0. That corresponds to a case where any asset
     * would represent an infinite amount of shares.
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual override returns (uint256 shares) {
        uint256 totalSup = totalSupply();
        uint256 totalAss = totalAssets().mulDiv(BPS_MULTIPLE - withdrawFeeBPS, BPS_MULTIPLE, Math.Rounding.Down);
        return
            (assets == 0 || totalAss == 0)
                ? assets.mulDiv(10**decimals(), 10**IERC20Metadata(asset()).decimals(), rounding)
                : assets.mulDiv(totalSup, totalAss, rounding);
    }

    /**
     * @dev Internal conversion function (from shares to assets) with support for rounding direction.
     * Copied from OpenZeppelin and updated to include withdraw fee.
     */
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual override returns (uint256 assets) {
        uint256 totalSup = totalSupply();
        uint256 totalAss = totalAssets().mulDiv(BPS_MULTIPLE - withdrawFeeBPS, BPS_MULTIPLE, Math.Rounding.Down);
        return
            (totalSup == 0)
                ? shares.mulDiv(10**IERC20Metadata(asset()).decimals(), 10**decimals(), rounding)
                : shares.mulDiv(totalAss, totalSup, rounding);
    }

    function _basisPercent (address owner, uint256 shares) internal virtual returns (uint256 assets) {
        assets = _basis[owner].mulDiv(shares, balanceOf(owner), Math.Rounding.Up);
        if (assets > _basis[owner]) assets = _basis[owner];
    }

    // following 3 functions MUST call super to make sure they don't override access control
    function _deposit (
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        _basis[receiver] += assets;
        updateTotalBasis(toInt256(assets));
        super._deposit(caller, receiver, assets, shares);
    }

    function _withdraw (
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        uint256 basis = _basisPercent(owner, shares);
        _basis[owner] -= basis;
        updateTotalBasis(-toInt256(basis));
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        uint256 basis = _basisPercent(from, amount);
        _basis[from] -= basis;
        _basis[to] += basis;
        super._transfer(from, to, amount);
    }

    // copied from OpenZeppelin SafeCast - didn't want the whole library
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}