// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

/// @notice ERC4626Accounting - enhance the OpenZeppelin ERC4626 base implementation to include basic balance sheet functions
   
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";    

abstract contract ERC4626Acounting is ERC4626 {

    function totalAssets() public view virtual override returns (uint256) {
        return _availableAssets() + totalNAV();
    }

     // use this for asset value of investments
    function totalNAV() public virtual view returns (uint256) {
        return 0;
    }

    function totalLiabilities() public view virtual returns (uint256) {
        return 0;
    }

    function totalEquity() public view virtual returns (uint256) {
        uint256 totAssets = totalAssets();
        uint256 totLiabs = totalLiabilities();
        return (totLiabs > totAssets) ? 0 : totAssets - totLiabs;
    }

    // available assets should be actual liquid assets that are not reserved for something else
    function _availableAssets() internal virtual view returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
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