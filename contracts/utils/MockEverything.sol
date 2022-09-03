// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "../redemption/ERC4626Redemption.sol";
import "../access/ERC4626Access.sol";
import "../redemption/ERC4626Coupon.sol";
import "../fees/ERC4626Fee.sol";

/// @notice Vault instantiation for testing

contract MockEverything is ERC4626Coupon, ERC4626Redemption, ERC4626Access, ERC4626Fee {
    constructor(
        IERC20Metadata _asset,
        string memory _name,
        string memory _symbol,
        uint32 _annualFeeBPS, 
        uint32 _carryFeeBPS, 
        uint32 _withdrawFeeBPS, 
        bool _disableDiscretionaryFee, 
        bool _disableFeeAdvance
    ) ERC4626(_asset) ERC20(_name, _symbol) 
      ERC4626Fee(_annualFeeBPS, _carryFeeBPS, _withdrawFeeBPS, _disableDiscretionaryFee, _disableFeeAdvance) {}


    // Everything below here is just crap to satisfy the compiler about multiple inheritance

    function requireManager() internal view override(ERC4626Access, ERC4626SuiteContext) {
      return super.requireManager();
    }
    
    function _deposit (address caller, address receiver, uint256 assets, uint256 shares
    ) internal virtual override(ERC4626Access, ERC4626Fee, ERC4626Redemption, ERC4626) {
        return super._deposit(caller, receiver, assets, shares);
    }

    function _withdraw (address caller, address receiver, address owner, uint256 assets, uint256 shares
    ) internal virtual override(ERC4626Access, ERC4626Fee, ERC4626) {
        return super._withdraw(caller, receiver, owner, assets, shares);
    }

    function _transfer(address from, address to, uint256 amount
    ) internal virtual override(ERC4626Access, ERC4626Fee, ERC4626Redemption, ERC20) {
        return super._transfer(from, to, amount);
    }

    function redeem(uint256 shares, address receiver, address owner
    ) public virtual override(ERC4626, ERC4626Redemption, ERC4626Fee) returns (uint256) {
      return super.redeem(shares, receiver, owner); 
    }
   function withdraw(uint256 assets, address receiver, address owner
    ) public virtual override(ERC4626, ERC4626Redemption, ERC4626Fee) returns (uint256) {
      return super.withdraw(assets, receiver, owner);
    }

    function totalAssets() public view virtual override(ERC4626SuiteContext, ERC4626Fee) returns (uint256) {
      return super.totalAssets();
    }
    function availableAssets() public virtual override(ERC4626Coupon, ERC4626Redemption, ERC4626SuiteContext) view returns (uint256 avail) {
      return super.availableAssets();
    }

    function availableSupply() public virtual override(ERC4626Redemption, ERC4626SuiteContext) view returns (uint256 avail) {
      return super.availableSupply();
    }

    function maxDeposit(address owner) public view virtual override(ERC4626, ERC4626Access) returns (uint256) {
        return super.maxDeposit(owner);
    }
    function maxMint(address owner) public view virtual override(ERC4626, ERC4626Access) returns (uint256) {
        return super.maxRedeem(owner);
    }
    function maxWithdraw(address owner) public view virtual override(ERC4626Fee, ERC4626Access, ERC4626Redemption, ERC4626) returns (uint256) {
        return super.maxWithdraw(owner);
    }
    function maxRedeem(address owner) public view virtual override(ERC4626, ERC4626Redemption, ERC4626Access) returns (uint256) {
        return super.maxRedeem(owner);
    }
    function previewWithdraw(uint256 assets) public view virtual override(ERC4626, ERC4626Redemption) returns (uint256) {
        return super.previewWithdraw(assets);
    }

    /** @dev See {IERC4626-previewRedeem}. */
    function previewRedeem(uint256 shares) public view virtual override(ERC4626, ERC4626Redemption) returns (uint256) {
        return super.previewRedeem(shares);
    }

}