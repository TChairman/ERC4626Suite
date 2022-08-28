// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "../fees/ERC4626Fee.sol";

/// @notice Index Fund vault for ERC4626 investments, that includes the ability to do off-chain investing. 
/// @notice Manager decides when to invest/divest in any ERC4626 vault or off-chain investment.
/// @notice Gains are not computed until investments are updated, either by an investment, or a call to updateAssetValue or setOfflineNAV.

contract ERC4626Managed is ERC4626Fee {

    // Events
    event depositInvestmentEvent(address indexed vault, uint256 amount);
    event redeemInvestmentEvent(address indexed vault, uint256 amount);
    event makeOffChainInvestmentEvent(address indexed receiver, uint256 amount);
    event returnOffChainInvestmentEvent(address indexed investor, uint256 amount, uint256 basis);
    event setOffChainNAVEvent(uint256 oldNAV, uint256 newNAV);
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
    uint256 public offChainNAV;
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

    // Do checks to ensure unsafe casts are guaranteed
    function totalAssets() public view virtual override returns (uint256 assets) {
        int256 avail = availableAssets();
        if (avail < 0) {
            assets = (uint256(-avail) > investmentAssetsTotal + offChainNAV) ? 0 : investmentAssetsTotal + offChainNAV - uint256(-avail);
        } else {
            assets = investmentAssetsTotal + offChainNAV + uint256(avail);
        }
    }
    
    function makeOffChainInvestment(address receiver, uint256 amount) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        require(ERC20(asset()).transfer(receiver, amount), "Transfer failed");
        offChainNAV += amount;
        emit makeOffChainInvestmentEvent(receiver, amount);
    }

    function returnOffChainInvestment(address investor, uint256 amount, uint256 basis) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        require(basis <= offChainNAV, "basis larger than offChainNav");
        offChainNAV -= basis;
        require(ERC20(asset()).transferFrom(investor, address(this), amount), "TransferFrom failed");
        emit returnOffChainInvestmentEvent(investor, amount, basis);
    }

    // update vault to reflect offline accounting for future deposits and withdrawals
    function setOffChainNAV(uint256 amount) public virtual onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256 oldNAV) {
        oldNAV = offChainNAV;
        offChainNAV = amount;
        emit setOffChainNAVEvent(oldNAV, amount);
    }

    function depositInvestment(ERC4626 _vault, uint256 _assets) public virtual onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256 _shares) {
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

    function redeemInvestment(ERC4626 _vault, uint256 _shares) public virtual onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256 _assets) {
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

    function forceTransferFrom(address from, address to, uint256 amount) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!disableForceTransfer, "Force transfers disabled");
        require(transferFrom(from, to, amount), "Force transfer failed");
        emit forceTransferFromEvent(from, to, amount);
    }
 
}
