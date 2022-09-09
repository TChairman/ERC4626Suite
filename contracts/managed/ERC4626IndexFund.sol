// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "../fees/ERC4626Fee.sol";
import "../access/ERC4626Access.sol";

/// @notice Index Fund vault for ERC4626 investments. Manager decides when to invest/divest in any ERC4626 vault.
/// @notice Gains are not computed until investments are updated, either by an investment, or a call to updateAssetValue.

contract ERC4626IndexFund is ERC4626Fee, ERC4626Access {

/*
Key things to think about:
If underlying asset values change dramatically, there will be an arb opportunity before they
get updated here. Not sure how to handle that. Can do more frequent updating with round-robin
but the problem still remains.
*/
/* Potential optimization to add:
   uint256 nextInvestmentToUpdate; // every tx updates at least one other investment too, spread the cost
   uint256 updateQuantum = 1000; // don't update if already updated this recently
   function updateNextAssetValue() - call from every tx to update next in line
*/

    // Events
    event depositInvestmentEvent(address indexed vault, uint256 amount);
    event redeemInvestmentEvent(address indexed vault, uint256 amount);
    event forceTransferFromEvent(address indexed from, address indexed to, uint256 amount);

    // Constants
    uint8 constant MAXINVESTMENTS = 255;

    // Variables
    struct investment {
        ERC4626 vault;
        uint256 lastAssets;
    }
    investment[] investments; // keep track of all the investments
    mapping(address => uint32) public investmentIndex; // so we can look them up easily
    uint256 investmentAssetsTotal;
    bool immutable public disableForceTransfer; // many vaults need forceTransfer for regulatory reasons, others may want to disable

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        uint32 _annualFeeBPS, 
        uint32 _carryFeeBPS, 
        uint32 _withdrawFeeBPS, 
        bool _disableDiscretionaryFee, 
        bool _disableFeeAdvance,
        bool _disableForceTransfer
    ) ERC4626(_asset) ERC20(_name, _symbol)
      ERC4626Fee(_annualFeeBPS, _carryFeeBPS, _withdrawFeeBPS, _disableDiscretionaryFee, _disableFeeAdvance)
    {
        disableForceTransfer = _disableForceTransfer;
    }

    // Investment manager functions

    // used in totalAssets()
    function totalNAV () public view virtual override returns (uint256) {
        return investmentAssetsTotal;
    }
    
    function depositInvestment(ERC4626 _vault, uint256 _assets) public virtual onlyManager returns (uint256 _shares) {
        require(_vault.asset() == asset(), "Investment asset does not match vault");

        uint32 index = investmentIndex[address(_vault)];
        if (investments[index].vault != _vault) { // new investment vault, index was zero
            index = uint32(investments.length);
            require(index < MAXINVESTMENTS, "Investment would exceed MAXINVESTMENTS");
            investmentIndex[address(_vault)] = index;
            investments[index].vault = _vault;
        }

        _shares = _vault.deposit(_assets, address(this));
        updateAssetValueIndex(index);
        emit depositInvestmentEvent(address(_vault), _assets);
    }

    function redeemInvestment(ERC4626 _vault, uint256 _shares) public virtual onlyManager returns (uint256 _assets) {
        uint32 index = investmentIndex[address(_vault)];
        uint256 sharesMax = _vault.maxWithdraw(address(this));
        if (_shares > sharesMax) _shares = sharesMax;
        _assets = _vault.redeem(_shares, address(this), address(this));
        updateAssetValueIndex(index);
        emit redeemInvestmentEvent(address(_vault), _shares);
    }

    function updateAssetValueIndex(uint32 index) internal virtual returns (uint256 assets) {
        require(index < investments.length, "Index out of range");
        assets = investments[index].vault.maxWithdraw(address(this));  // won't take into account all fees, but close enough
        investmentAssetsTotal += assets - investments[index].lastAssets;
        investments[index].lastAssets = assets;
    }

    // anyone can update a single vault asset value
    function updateAssetValue(ERC4626 _vault) public virtual returns (uint256) {
        return updateAssetValueIndex(investmentIndex[address(_vault)]);
    }

    // probably costs a lot of gas, but here just in case a full reset is needed
    function updateAllAssets() public virtual returns (uint256) {
        investmentAssetsTotal = 0;
        for(uint8 i=0; i<= investments.length; i++){
            investmentAssetsTotal += investments[i].vault.maxWithdraw(address(this));
        }
        return investmentAssetsTotal;
    }

    function forceTransferFrom(address from, address to, uint256 amount) public virtual onlyManager {
        require(!disableForceTransfer, "Force transfers disabled");
        require(transferFrom(from, to, amount), "Force transfer failed");
        emit forceTransferFromEvent(from, to, amount);
    }

    // Everything below here is just crap to satisfy the compiler about multiple inheritance
    function requireManager() internal view override(ERC4626Access, ERC4626SuiteContext) {
      return super.requireManager();
    }
    
    function _deposit (address caller, address receiver, uint256 assets, uint256 shares
    ) internal virtual override(ERC4626, ERC4626Fee) {
        return super._deposit(caller, receiver, assets, shares);
    }

    function _withdraw (address caller, address receiver, address owner, uint256 assets, uint256 shares
    ) internal virtual override(ERC4626, ERC4626Fee) {
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
    function maxWithdraw(address owner) public view virtual override(ERC4626Fee, ERC4626Access) returns (uint256) {
        return super.maxWithdraw(owner);
    }
    function maxRedeem(address owner) public view virtual override(ERC4626, ERC4626Access) returns (uint256) {
        return super.maxRedeem(owner);
    }

}
