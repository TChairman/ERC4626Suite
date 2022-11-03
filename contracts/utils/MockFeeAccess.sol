// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author The Chairman (https://github.com/TChairman/ERC4626Suite)

import "../liabilities/ERC4626Fee.sol";
import "../equity/ERC4626Access.sol";

/// @notice Vault instantiation for testing

contract MockFeeAccess is ERC4626Fee, ERC4626Access {
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

    function requireManager() internal view override(ERC4626Access, ERC4626SuiteContext) {
      return super.requireManager();
    }
    
    function _deposit (address caller, address receiver, uint256 assets, uint256 shares
    ) internal virtual override(ERC4626SuiteContext, ERC4626Fee) {
        return super._deposit(caller, receiver, assets, shares);
    }

    function _withdraw (address caller, address receiver, address owner, uint256 assets, uint256 shares
    ) internal virtual override(ERC4626SuiteContext, ERC4626Fee) {
        return super._withdraw(caller, receiver, owner, assets, shares);
    }

    function _transfer(address from, address to, uint256 amount
    ) internal virtual override(ERC20, ERC4626Fee) {
        return super._transfer(from, to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20, ERC4626Access) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function redeem(uint256 shares, address receiver, address owner
    ) public virtual override(ERC4626, ERC4626Fee) returns (uint256) {
      return super.redeem(shares, receiver, owner); 
    }

   function withdraw(uint256 assets, address receiver, address owner
    ) public virtual override(ERC4626, ERC4626Fee) returns (uint256) {
      return super.withdraw(assets, receiver, owner);
    }

    function actualAssets() public view virtual override(ERC4626SuiteContext, ERC4626Fee) returns (uint256) {
      return super.actualAssets();
    }
    function totalLiabilities() public view virtual override(ERC4626SuiteContext, ERC4626Fee) returns (uint256) {
      return super.totalLiabilities();
    }
    function maxDeposit(address owner) public view virtual override(ERC4626, ERC4626Access) returns (uint256) {
        return super.maxDeposit(owner);
    }
    function maxMint(address owner) public view virtual override(ERC4626, ERC4626Access) returns (uint256) {
        return super.maxRedeem(owner);
    }
    function maxWithdraw(address owner) public view virtual override(ERC4626Fee, ERC4626Access) returns (uint256) {
        return super.maxWithdraw(owner);
    }
    function maxRedeem(address owner) public view virtual override(ERC4626, ERC4626Access) returns (uint256) {
        return super.maxRedeem(owner);
    }

}