// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author The Chairman (https://github.com/TChairman/ERC4626Suite)

/// @notice ERC4626SuiteContext - enhance the OpenZeppelin ERC4626 base implementation with hooks and functions used in most other Suite contracts
   
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";    

abstract contract ERC4626SuiteContext is ERC4626 {

    uint32 constant BPS_MULTIPLE = 10000;
    uint32 public immutable DAYS_PER_YEAR = 360; // many funds use 360 day year; if updated be sure to update SECS_PER_YEAR below too
    uint32 public immutable SECS_PER_YEAR = 360 * 24 * 60 * 60;

    // this needs to be implemented if not using ERC4626Access
    function requireManager() internal virtual view;

    modifier onlyManager() virtual {
        requireManager();
        _;
    }

    // available assets should be actual liquid assets that are not reserved for something else
    function availableAssets() public virtual view returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

     // use this for asset value of investments
    function totalNAV() public virtual view returns (uint256) {
        return 0;
    }

    // should be totalAssets, but that's taken by ERC4626 for equity value
    function actualAssets() public view virtual returns (uint256) {
        return availableAssets() + totalNAV();
    }

    function totalLiabilities() public view virtual returns (uint256) {
        return 0;
    }

    // I consider this a naming bug in ERC4626 - totalAssets should actually be totalEquity or netAssets, because it is used for share price conversion
    // equity = total assets - total liabilities, share price should be based on equity (net asset) value, not total assets
    // but for backwards compatibility with ERC4626, we are keeping the name, and using actualAssets for total assets
    function totalAssets() public view virtual override returns (uint256) {
        uint256 actAssets = actualAssets();
        uint256 totLiabs = totalLiabilities();
        if (totLiabs > actAssets) totLiabs = actAssets;
        return actAssets - totLiabs;
    }

    // put in some useful hooks for fees and other things

    function _beforeWithdraw(address owner, uint256 assets, uint256 shares) internal virtual {}

    function _afterDeposit(address owner, uint256 assets, uint256 shares) internal virtual {}

    function _withdraw (
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        _beforeWithdraw(owner, assets, shares);
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    function _deposit (
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        super._deposit(caller, receiver, assets, shares);
        _afterDeposit(receiver, assets, shares);
    }

}