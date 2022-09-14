// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "./ERC4626AssetBase.sol";
import "./interfaces/IFixedInterestOnlyLoans.sol";

/// @notice Support for TrueFi Fixed Interest Only Loans
/// @notice Payments are not checked for correctness, they should be validated off chain

abstract contract ERC4626AssetFIOL is ERC4626AssetBase {
    using Math for uint256;

    // Events
    bytes32 public constant FIOL_ASSET = keccak256("FIOL_ASSET");
    IFixedInterestOnlyLoans public immutable FIOLcontract;

    constructor(IFixedInterestOnlyLoans _FIOLcontract) {
        FIOLcontract = _FIOLcontract;
    }

    function distributeCoupon(uint256 _coupon) public virtual;

    function getLatestNAV(assetStruct storage asset) internal view virtual override returns (uint256) {
        if (asset.assetType == FIOL_ASSET) {
            return IFixedInterestOnlyLoans(asset.assetAddress).principal(asset.assetReference); // FIOL doesn't seem to have a way to estimate inter-period interest accrued
        } else {
            return super.getLatestNAV(asset);
        }
    }

    function createFIOL(uint256 _principal, uint16 _periodCount, uint256 _periodPayment, uint32 _periodDuration, address _recipient) public virtual onlyManager {
        uint256 loanID = FIOLcontract.issueLoan(IERC20WithDecimals(asset()), _principal, _periodCount, _periodPayment, _periodDuration, _recipient, 0, true);
        createAsset(FIOL_ASSET, address(FIOLcontract), loanID, 0, 0); // start with 0 balance until funded
    }

    function fundFIOL(uint256 _loanID) public virtual onlyManager returns (uint256 _principal) {
        _principal = FIOLcontract.principal(_loanID);
        FIOLcontract.start(_loanID);
        require(IERC20(asset()).transfer(FIOLcontract.recipient(_loanID), _principal), "fundFIOL: transfer failed");
    }

    function repayFIOL(uint256 _loanID, uint256 _amount) public virtual {
        (, uint256 interest) = FIOLcontract.repay(_loanID, _amount);
        updateNAV(address(FIOLcontract), _loanID);
        distributeCoupon(interest);
    }

}