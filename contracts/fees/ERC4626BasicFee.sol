// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/// @notice ERC4626 tokenized Vault implementation with withdrawal fees and immediate fee transfer
/// @notice based on OpenZeppelin v4.7 (token/ERC20/extensions/ERC4626.sol)

// TODO consider making this clonable and therefore initializable

abstract contract ERC4626BasicFee is ERC4626 {
    using Math for uint256;

    uint32 constant BPS_MULTIPLE = 10000;
    address public feeAddress; // if you implement setFeeAddress, make sure you specify onlyOwner or otherwise secure it
    uint32 public immutable withdrawFeeBPS;

    constructor(address _feeAddress, uint32 _withdrawFeeBPS) {
        feeAddress = _feeAddress;
        require(_withdrawFeeBPS < 10000, "Withdraw Fee must be less than 100%");
        withdrawFeeBPS = _withdrawFeeBPS;
    }

    // for compatibility with ERC4626Fees.sol
/*    function availableAssets() public virtual returns (int256) {
        uint256 avail = IERC20(asset()).balanceOf(address(this));
        require(avail <= uint256(type(int256).max), "availableAssets: value doesn't fit in an int256");
        return int256(avail);        
    }
  */  
    // Functions overridden from ERC4626

    /** @dev See {IERC4626-maxWithdraw}. */
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        return _convertToAssetsWithFee(balanceOf(owner), Math.Rounding.Down);
    }

    /** @dev See {IERC4626-previewWithdraw}. */
    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        return _convertToSharesWithFee(assets, Math.Rounding.Up);
    }

    /** @dev See {IERC4626-previewRedeem}. */
    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssetsWithFee(shares, Math.Rounding.Down);
    }

    /** @dev See {IERC4626-withdraw}. */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(assets <= maxWithdraw(owner), "ERC4626: withdraw more than max");

        uint256 shares = _convertToSharesWithFee(assets, Math.Rounding.Up);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
        uint256 feeAmount = assets.mulDiv(withdrawFeeBPS, BPS_MULTIPLE - withdrawFeeBPS, Math.Rounding.Down);
        require(ERC20(asset()).transfer(feeAddress, feeAmount));

        return shares;
    }

    /** @dev See {IERC4626-redeem}. */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");

        uint256 assets = _convertToAssetsWithFee(shares, Math.Rounding.Down);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
        uint256 feeAmount = assets.mulDiv(withdrawFeeBPS, BPS_MULTIPLE - withdrawFeeBPS, Math.Rounding.Down);
        require(ERC20(asset()).transfer(feeAddress, feeAmount));

        return assets;
    }

    /**
     * @dev Internal conversion function (from assets to shares) with support for rounding direction.
     * Updated to include withdraw fee.
     *
     * Will revert if assets > 0, totalSupply > 0 and totalAssets = 0. That corresponds to a case where any asset
     * would represent an infinite amount of shares.
     */
    function _convertToSharesWithFee(uint256 assets, Math.Rounding rounding) internal view virtual returns (uint256 shares) {
        uint256 totalSup = totalSupply();
        uint256 netAss = totalAssets().mulDiv(BPS_MULTIPLE - withdrawFeeBPS, BPS_MULTIPLE, Math.Rounding.Down);
        return
            (assets == 0 || netAss == 0)
                ? assets.mulDiv(10**decimals(), 10**IERC20Metadata(asset()).decimals(), rounding)
                : assets.mulDiv(totalSup, netAss, rounding);
    }

    /**
     * @dev Internal conversion function (from shares to assets) with support for rounding direction.
     * Updated to include withdraw fee.
     */
    function _convertToAssetsWithFee(uint256 shares, Math.Rounding rounding) internal view virtual returns (uint256 assets) {
        uint256 totalSup = totalSupply();
        uint256 netAss = totalAssets().mulDiv(BPS_MULTIPLE - withdrawFeeBPS, BPS_MULTIPLE, Math.Rounding.Down);
        return
            (totalSup == 0)
                ? shares.mulDiv(10**IERC20Metadata(asset()).decimals(), 10**decimals(), rounding)
                : shares.mulDiv(netAss, totalSup, rounding);
    }

}
