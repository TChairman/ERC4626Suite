// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20WithDecimals} from "./IERC20WithDecimals.sol";
import {IDebtInstrument} from "./IDebtInstrument.sol";

enum FixedInterestOnlyLoanStatus {
    Created,
    Accepted,
    Started,
    Repaid,
    Canceled,
    Defaulted
}

interface IFixedInterestOnlyLoans is IDebtInstrument {
    struct LoanMetadata {
        uint256 principal;
        uint256 periodPayment;
        FixedInterestOnlyLoanStatus status;
        uint16 periodCount;
        uint32 periodDuration;
        uint40 currentPeriodEndDate;
        address recipient;
        bool canBeRepaidAfterDefault;
        uint16 periodsRepaid;
        uint32 gracePeriod;
        uint40 endDate;
        IERC20WithDecimals asset;
    }

    function issueLoan(
        IERC20WithDecimals _asset,
        uint256 _principal,
        uint16 _periodCount,
        uint256 _periodPayment,
        uint32 _periodDuration,
        address _recipient,
        uint32 _gracePeriod,
        bool _canBeRepaidAfterDefault
    ) external returns (uint256);

    function loanData(uint256 instrumentId) external view returns (LoanMetadata memory);

    function updateInstrument(uint256 _instrumentId, uint32 _gracePeriod) external;

    function status(uint256 instrumentId) external view returns (FixedInterestOnlyLoanStatus);
}