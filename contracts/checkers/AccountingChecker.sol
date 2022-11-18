// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console } from "../../modules/contract-test-utils/contracts/log.sol";

import {
    IERC20Like,
    ILoanManagerLike,
    IMapleGlobalsLike,
    IMapleLoanLike,
    ILoanManagerLike,
    IMapleLoanV4Like,
    IMapleProxyFactoryLike,
    IPoolManagerLike
} from "../interfaces/Interfaces.sol";

contract AccountingChecker {

    uint256 constant HUNDRED_PERCENT = 1e6;
    uint256 constant PRECISION       = 1e30;

    address public globals;

    constructor (address globals_) {
        globals = globals_;
    }

    function checkPoolAccounting(
        address poolManager_,
        address[] calldata loans_,
        uint256 loansAddedTimestamp_,
        uint256 lastUpdatedTimestamp_
    )
        external view returns (
            uint256 expectedTotalAssets_,
            uint256 actualTotalAssets_,
            uint256 expectedDomainEnd_,
            uint256 actualDomainEnd_
        )
    {
        uint256 totalPrincipal_;
        uint256 totalInterest_;

        for (uint256 i = 0; i < loans_.length; i++) {
            uint256 loanPaymentDueDate_ = IMapleLoanLike(loans_[i]).nextPaymentDueDate();

            if (expectedDomainEnd_ == 0 || (loanPaymentDueDate_ < expectedDomainEnd_ && loanPaymentDueDate_ > lastUpdatedTimestamp_)) {
                expectedDomainEnd_ = loanPaymentDueDate_;
            }
        }

        if (loans_.length == 0) {
            expectedDomainEnd_ = lastUpdatedTimestamp_;
        }

        actualDomainEnd_ = ILoanManagerLike(IPoolManagerLike(poolManager_).loanManagerList(0)).domainEnd();

        for (uint256 i = 0; i < loans_.length; i++) {
            ( uint256 principal_, uint256 accruedInterest_ ) = _checkAssetsUnderManagement(poolManager_, loans_[i], loansAddedTimestamp_, expectedDomainEnd_);
            totalPrincipal_ += principal_;
            totalInterest_  += accruedInterest_;
        }

        uint256 cash_ = IERC20Like(IPoolManagerLike(poolManager_).asset()).balanceOf(IPoolManagerLike(poolManager_).pool());

        expectedTotalAssets_ = totalPrincipal_ + totalInterest_ + cash_;
        actualTotalAssets_   = IPoolManagerLike(poolManager_).totalAssets();
    }

    function _checkAssetsUnderManagement(
        address poolManager_,
        address loanAddress_,
        uint256 loansAddedTimestamp_,
        uint256 expectedDomainEnd_
    )
        internal view returns (uint256 principal, uint256 accruedInterest)
    {
        uint256 managementFeeRate_;

        {
            uint256 delegateManagementFeeRate_ = IPoolManagerLike(poolManager_).delegateManagementFeeRate();
            uint256 platformManagementFeeRate_ = IMapleGlobalsLike(globals).platformManagementFeeRate(poolManager_);

            managementFeeRate_ = delegateManagementFeeRate_+ platformManagementFeeRate_;

            // NOTE: If combined fee is greater than 100%, then cap delegate fee and clamp management fee.
            if (managementFeeRate_ > HUNDRED_PERCENT) {
                delegateManagementFeeRate_ = HUNDRED_PERCENT - platformManagementFeeRate_;
                managementFeeRate_         = HUNDRED_PERCENT;
            }
        }

        IMapleLoanLike loan_ = IMapleLoanLike(loanAddress_);

        uint256 refinanceInterest_ = loan_.refinanceInterest();
        uint256 grossInterest_     = _getGrossInterest(loanAddress_);

        uint256 incomingNetInterest_  = _getNetInterest(grossInterest_ - refinanceInterest_, managementFeeRate_);
        uint256 netRefinanceInterest_ = _getNetInterest(refinanceInterest_,                  managementFeeRate_);

        uint256 nextPaymentDueDate_ = loan_.nextPaymentDueDate();

        uint256 startDate_ = _min(nextPaymentDueDate_ - loan_.paymentInterval(), loansAddedTimestamp_);
        uint256 endDate_   = _min(block.timestamp, _min(nextPaymentDueDate_, expectedDomainEnd_));

        principal       = loan_.principal();
        accruedInterest = netRefinanceInterest_ + incomingNetInterest_ * (endDate_ - startDate_) / (nextPaymentDueDate_ - startDate_);
    }

    function _getGrossInterest(address loan_) internal view returns (uint256 grossInterest_) {
        uint256 version_ = _getVersion(loan_);

        if (version_ == 301 || version_ == 302) {
            ( , grossInterest_, , ) = IMapleLoanLike(loan_).getNextPaymentBreakdown();
        } else if (version_ == 400) {
            ( , grossInterest_, ) = IMapleLoanV4Like(loan_).getNextPaymentBreakdown();
        } else {
            revert("AC:UNSUPPORTED_LOAN");
        }
    }

    function _getNetInterest(uint256 interest_, uint256 feeRate_) internal pure returns (uint256 netInterest_) {
        netInterest_ = interest_ * (HUNDRED_PERCENT - feeRate_) / HUNDRED_PERCENT;
    }

    function _getVersion(address loan_) internal view returns (uint256 version_) {
        version_ = IMapleProxyFactoryLike(IMapleLoanLike(loan_).factory()).versionOf(IMapleLoanLike(loan_).implementation());
    }

    function _max(uint256 a_, uint256 b_) internal pure returns (uint256 maximum_) {
        maximum_ = a_ > b_ ? a_ : b_;
    }

    function _min(uint256 a_, uint256 b_) internal pure returns (uint256 minimum_) {
        minimum_ = a_ < b_ ? a_ : b_;
    }

}
