// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "../liabilities/ERC4626Fee.sol";
import "../equity/ERC4626Access.sol";
import "../equity/ERC4626Force.sol";
import "../assets/ERC4626Asset4626.sol";
import "../assets/ERC4626AssetOffChain.sol";

/// @notice Index Fund vault for ERC4626 investments. Manager decides when to invest/divest in any ERC4626 vault.
/// @notice Gains are not computed until investments are updated, either by an investment, or a call to updateAssetValue.

contract ERC4626IndexFund is ERC4626Asset4626, ERC4626AssetOffChain, ERC4626Fee, ERC4626Access, ERC4626Force {

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        uint32 _annualFeeBPS, 
        uint32 _carryFeeBPS, 
        uint32 _withdrawFeeBPS, 
        bool _disableDiscretionaryFee, 
        bool _disableFeeAdvance
    ) ERC4626(_asset) ERC20(_name, _symbol)
      ERC4626Fee(_annualFeeBPS, _carryFeeBPS, _withdrawFeeBPS, _disableDiscretionaryFee, _disableFeeAdvance)
    {
    }

    // interesting - all the logic is in the components
    function distributeCoupon(uint256 _coupon) public virtual override {}

    // Everything below here is just crap to satisfy the compiler about multiple inheritance
    function totalNAV() public virtual override(ERC4626AssetBase, ERC4626SuiteContext) view returns (uint256) {
        return super.totalNAV();
    }
    
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
    ) internal virtual override(ERC4626Fee, ERC20) {
        return super._transfer(from, to, amount);
    }
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC4626Access) {
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

    function totalAssets() public view virtual override(ERC4626SuiteContext, ERC4626Fee) returns (uint256) {
      return super.totalAssets();
    }
    function maxDeposit(address owner) public view virtual override(ERC4626, ERC4626Access) returns (uint256) {
        return super.maxDeposit(owner);
    }
    function maxMint(address owner) public view virtual override(ERC4626, ERC4626Access) returns (uint256) {
        return super.maxRedeem(owner);
    }
    function maxWithdraw(address owner) public view virtual override(ERC4626, ERC4626Fee, ERC4626Access) returns (uint256) {
        return super.maxWithdraw(owner);
    }
    function maxRedeem(address owner) public view virtual override(ERC4626, ERC4626Access) returns (uint256) {
        return super.maxRedeem(owner);
    }
    function getLatestNAV(assetStruct storage asset) internal view virtual override(ERC4626AssetBase, ERC4626Asset4626) returns (uint256) {
        return super.getLatestNAV(asset);
    }

}
