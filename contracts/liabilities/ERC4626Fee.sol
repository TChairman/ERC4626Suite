// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "../ERC4626SuiteContext.sol";
import "./ERC4626ProtocolFeeConfig.sol";

/// @notice ERC4626 tokenized Vault implementation with annual, carry, and withdraw fees
/// @notice based on OpenZeppelin v4.7 (token/ERC20/extensions/ERC4626.sol)


// Test to make sure this works when fee accrual exceeds free token balance, this may be common


abstract contract ERC4626Fee is ERC4626SuiteContext, ERC4626ProtocolFeeConfig {
    using Math for uint256;

    // Constants / immutables
    uint32 public immutable annualFeeBPS;
    uint32 public immutable carryFeeBPS;
    uint32 public immutable withdrawFeeBPS;
    bool public immutable disableDicretionaryFee;
    bool public immutable disableFeeAdvance;

    // Variables
    mapping (address => uint256) private _paidIn;
    mapping (address => uint256) private _paidOut;
    uint256 public totalPaidIn;
    uint256 public totalPaidOut;
    int256 public accruedFees; // may be negative if fee advances are made
    uint256 internal lastAnnualFeeAccrual;

    // Events
    event discretionaryFeeEvent(int256 amount, string reason);
    event drawFeeEvent(address to, uint256 amount);
    event repayFeeEvent(address from, uint256 amountn);

    constructor(uint32 _annualFeeBPS, uint32 _carryFeeBPS, uint32 _withdrawFeeBPS, bool _disableDiscretionaryFee, bool _disableFeeAdvance) {
        require(_annualFeeBPS + protocolAnnualFeeBPS < 10000, "Annual Fee must be less than 100%");
        annualFeeBPS = _annualFeeBPS + protocolAnnualFeeBPS;
        require(_carryFeeBPS + protocolCarryFeeBPS < 10000, "Carry Fee must be less than 100%");
        carryFeeBPS = _carryFeeBPS + protocolCarryFeeBPS;
        require(_withdrawFeeBPS + protoocolWithdrawFeeBPS < 10000, "Withdraw Fee must be less than 100%");
        withdrawFeeBPS = _withdrawFeeBPS + protoocolWithdrawFeeBPS;
        disableDicretionaryFee = _disableDiscretionaryFee ;
        disableFeeAdvance = _disableFeeAdvance;
    }

    function actualAssets() public view virtual override returns (uint256 assets) {
        int256 fees = totalAccruedFees();
        assets = super.actualAssets();
        if (fees > 0) assets += uint256(-fees);
    }

    function totalLiabilities() public view virtual override returns (uint256 liabs) {
        int256 fees = totalAccruedFees();
        liabs = super.totalLiabilities();
        if (fees < 0) liabs += uint256(fees);
    }

    function accrueFee(int256 fee) internal virtual {
        accruedFees += fee;
    }

    function splitAndAccrueFee(uint256 fee, uint32 feeTotalBPS, uint32 protocolBPS) internal virtual {
        if (feeTotalBPS == 0) return;
        uint256 protocolFee = fee.mulDiv(protocolBPS, feeTotalBPS);
        require(IERC20(asset()).transfer(protocolTreasury, protocolFee), "splitAndAccrueFee: Transfer failed");
        accrueFee(toInt256(fee - protocolFee));
    }

    function accruedAnnualFee() public virtual view returns (uint256) {
        return totalPaidIn.mulDiv(annualFeeBPS, BPS_MULTIPLE, Math.Rounding.Down).mulDiv(block.timestamp - lastAnnualFeeAccrual, DAYS_PER_YEAR);
    }

    function totalAccruedFees() public virtual view returns (int256) {
        return accruedFees + toInt256(accruedAnnualFee());
    }

    function updateAnnualFee() public virtual {
        splitAndAccrueFee(accruedAnnualFee(), annualFeeBPS, protocolAnnualFeeBPS);
        lastAnnualFeeAccrual = block.timestamp;
    }

    // amount could be negative to correct errors
    function recordDiscretionaryFee (int256 amount, string memory reason) public virtual onlyManager {
        require(!disableDicretionaryFee, "Discretionary fees disabled");
        accrueFee(amount);
        emit discretionaryFeeEvent(amount, reason);
    }

    // can draw more than accrued if advances allowed
    function drawFee (address to, uint256 amount) public virtual onlyManager {
        updateAnnualFee();
        require(!disableFeeAdvance || (toInt256(amount) <= accruedFees), "Advancing fees disabled");
        accrueFee(-toInt256(amount));
        require(IERC20(asset()).transfer(to, amount), "drawFee: Transfer failed");
        emit drawFeeEvent(to, amount);
    }

    // seems a little silly, but important for accounting
    // fee repaid stays accrued, call recordDiscretionaryFee with a negative amount to return to LPs
    function repayFee (address from, uint256 amount) public virtual onlyManager {
        require(IERC20(asset()).transferFrom(from, address(this), amount), "repayFee: Transfer failed");
        accrueFee(toInt256(amount));
        emit repayFeeEvent(from, amount);
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
        (assets, , ) = _convertToAssetsNetFees(balanceOf(owner), owner);
    }

    /** @dev See {IERC4626-withdraw}. */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(assets <= maxWithdraw(owner), "ERC4626: withdraw more than max");

        (uint256 shares, uint256 withdrawFee, uint256 carryFee) = _convertToSharesNetFees(assets, owner);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
        splitAndAccrueFee(withdrawFee, protoocolWithdrawFeeBPS, withdrawFeeBPS);
        splitAndAccrueFee(carryFee, protocolCarryFeeBPS, carryFeeBPS);
        
        return shares;
    }

    /** @dev See {IERC4626-redeem}. */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");

        (uint256 assets, uint256 withdrawFee, uint256 carryFee) = _convertToAssetsNetFees(shares, owner);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
        splitAndAccrueFee(withdrawFee, protoocolWithdrawFeeBPS, withdrawFeeBPS);
        splitAndAccrueFee(carryFee, protocolCarryFeeBPS, carryFeeBPS);

        return assets;
    }

    function netAssets(address owner) public virtual view returns (uint256 assets, uint256 withdrawFee, uint256 carryFee) {
        uint256 availSup = totalSupply();
        if (availSup == 0) return (0,0,0);
        assets = balanceOf(owner).mulDiv(totalAssets(), availSup); // what owner would have with only annual fees accrued

        // calculate carry fee
        if (carryFeeBPS > 0) {
            int256 gainLoss = toInt256(assets + _paidOut[owner]) - toInt256(_paidIn[owner]);
            if (gainLoss > 0) { // unsafe cast below is okay because we check for > 0 here
                carryFee = uint256(gainLoss).mulDiv(carryFeeBPS, BPS_MULTIPLE, Math.Rounding.Up);
                assets -= carryFee;
            }
        }

        // calculate withdraw fee
        if (withdrawFeeBPS > 0) {
            withdrawFee = assets.mulDiv(withdrawFeeBPS, BPS_MULTIPLE, Math.Rounding.Up);
            assets -= withdrawFee;
        }
    }
    
    function _convertToSharesNetFees(uint256 assets, address owner) internal view virtual returns (uint256 shares, uint256 withdrawFee, uint256 carryFee) {
        (uint256 netAss, uint256 netWithdrawFee, uint256 netCarryFee) = netAssets(owner);
        shares = balanceOf(owner).mulDiv(assets, netAss, Math.Rounding.Up);
        withdrawFee = netWithdrawFee.mulDiv(assets, netAss, Math.Rounding.Down);
        carryFee = netCarryFee.mulDiv(assets, netAss, Math.Rounding.Down);
    }

    function _convertToAssetsNetFees(uint256 shares, address owner) internal view virtual returns (uint256 assets, uint256 withdrawFee, uint256 carryFee) {
        (uint256 netAss, uint256 netWithdrawFee, uint256 netCarryFee) = netAssets(owner);
        assets = netAss.mulDiv(shares, balanceOf(owner), Math.Rounding.Down);
        withdrawFee = netWithdrawFee.mulDiv(assets, netAss, Math.Rounding.Down);
        carryFee = netCarryFee.mulDiv(assets, netAss, Math.Rounding.Down);
    }

    // following 3 functions MUST call super to make sure they don't override access control
    function _deposit (
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        _paidIn[receiver] += assets;
        totalPaidIn += assets;
        super._deposit(caller, receiver, assets, shares);
    }

    function _withdraw (
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        _paidOut[owner] += assets;
        totalPaidOut += assets;
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    function _transfer(
        address from,
        address to,
        uint256 shares
    ) internal virtual override {
        (uint256 assets, uint256 withdrawFee, uint256 carryFee) = _convertToAssetsNetFees(shares, from);
        splitAndAccrueFee(withdrawFee, protoocolWithdrawFeeBPS, withdrawFeeBPS);
        splitAndAccrueFee(carryFee, protocolCarryFeeBPS, carryFeeBPS);
        _paidOut[from] += assets; // TODO fix this - doesn't update totalPaidIn, but does it matter?
        _paidIn[to] += assets;
        super._transfer(from, to, shares);
    }

    // copied from OpenZeppelin SafeCast - didn't want the whole library
    function toInt256(uint256 value) private pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}