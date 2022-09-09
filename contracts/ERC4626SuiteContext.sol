// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

/// @notice ERC4626SuiteContect functions used in most other Suite contracts
   
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";    

abstract contract ERC4626SuiteContext is ERC4626 {

    uint32 constant BPS_MULTIPLE = 10000;
    uint32 constant DAYS_PER_YEAR = 360; // many funds use 360 day year

    // this should be overridden if not using Access, default to revert
    function requireManager() internal virtual view;

    modifier onlyManager() virtual {
        requireManager();
        _;
    }

    // can be overridden and adjusted by child contracts
    function availableAssets() public virtual view returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    function availableSupply() public virtual view returns (uint256) {
        return totalSupply();
    }
     // override this so you don't have to re-implement totalAssets() below
    function totalNAV() public virtual view returns (uint256) {
        return 0;
    }

    function totalAssets() public view virtual override returns (uint256) {
        return availableAssets() + totalNAV();
    }

}