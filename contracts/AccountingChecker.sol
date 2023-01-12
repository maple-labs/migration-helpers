// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IAccountingChecker } from "./interfaces/IAccountingChecker.sol";

import {
    IERC20Like,
    ILoanManagerLike,
    IMapleGlobalsLike,
    IMapleLoanLike,
    IMapleLoanV4Like,
    IMapleProxyFactoryLike,
    IPoolManagerLike
} from "./interfaces/Interfaces.sol";

contract AccountingChecker is IAccountingChecker {

    uint256 public constant override HUNDRED_PERCENT = 1e6;
    uint256 public constant override PRECISION       = 1e30;
    uint256 public constant override SCALED_ONE      = 1e18;

    address public override globals;

    constructor (address globals_) {
        globals = globals_;
    }

    function checkPoolAccounting(
        address poolManager_,
        address[] calldata loans_,
        uint256 loansAddedTimestamp_,
        uint256 lastUpdatedTimestamp_
    )
        external view override
        returns (
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
            (
                uint256 principal_,
                uint256 accruedInterest_
            ) = _checkAssetsUnderManagement(poolManager_, loans_[i], loansAddedTimestamp_, expectedDomainEnd_);

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
            // NOTE: This will return the wrong values if we update the management fees on mainnet.
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

        ( uint256 grossInstallmentInterest_, uint256 grossRefinanceInterest_ ) = _getGrossInterestParams(loanAddress_);

        uint256 incomingNetInterest_  = _getNetInterest(grossInstallmentInterest_, managementFeeRate_);
        uint256 netRefinanceInterest_ = _getNetInterest(grossRefinanceInterest_,   managementFeeRate_);

        uint256 nextPaymentDueDate_ = loan_.nextPaymentDueDate();

        uint256 startDate_ = _min(nextPaymentDueDate_ - loan_.paymentInterval(), loansAddedTimestamp_);
        uint256 endDate_   = _min(block.timestamp, _min(nextPaymentDueDate_, expectedDomainEnd_));

        principal       = loan_.principal();
        accruedInterest = netRefinanceInterest_ + incomingNetInterest_ * (endDate_ - startDate_) / (nextPaymentDueDate_ - startDate_);
    }

    function _getGrossInterestParams(address loan_)
        internal view returns (uint256 grossInstallmentInterest_, uint256 grossRefinanceInterest_)
    {
        uint256 version_ = _getVersion(loan_);

        if (version_ == 301 || version_ == 302) {
            ( , grossInstallmentInterest_, , ) = IMapleLoanLike(loan_).getNextPaymentBreakdown();
            grossRefinanceInterest_ = IMapleLoanLike(loan_).refinanceInterest();

            grossInstallmentInterest_ -= (_getLateInterest(loan_) + grossRefinanceInterest_);
        } else if (version_ == 400) {
            ( , uint256[3] memory interest_, ) = IMapleLoanV4Like(loan_).getNextPaymentDetailedBreakdown();
            grossInstallmentInterest_ = interest_[0];
            grossRefinanceInterest_   = interest_[2];
        } else {
            revert("AC:UNSUPPORTED_LOAN");
        }
    }

    function _getLateInterest(address loan_) internal view returns (uint256 lateInterest_) {
        uint256 principal_           = IMapleLoanLike(loan_).principal();
        uint256 interestRate_        = IMapleLoanLike(loan_).interestRate();
        uint256 nextPaymentDueDate_  = IMapleLoanLike(loan_).nextPaymentDueDate();
        uint256 lateFeeRate_         = IMapleLoanLike(loan_).lateFeeRate();
        uint256 lateInterestPremium_ = IMapleLoanLike(loan_).lateInterestPremium();

        if (block.timestamp <= nextPaymentDueDate_) return 0;

        uint256 fullDaysLate = (((block.timestamp - nextPaymentDueDate_ - 1) / 1 days) + 1) * 1 days;

        lateInterest_ += _getInterest(principal_, interestRate_ + lateInterestPremium_, fullDaysLate);
        lateInterest_ += (lateFeeRate_ * principal_) / SCALED_ONE;
    }

    function _getInterest(uint256 principal_, uint256 interestRate_, uint256 interval_) internal pure returns (uint256 interest_) {
        interest_ = principal_ * _getPeriodicInterestRate(interestRate_, interval_) / SCALED_ONE;
    }

    function _getNetInterest(uint256 interest_, uint256 feeRate_) internal pure returns (uint256 netInterest_) {
        netInterest_ = interest_ * (HUNDRED_PERCENT - feeRate_) / HUNDRED_PERCENT;
    }

    function _getPeriodicInterestRate(uint256 interestRate_, uint256 interval_) internal pure returns (uint256 periodicInterestRate_) {
        periodicInterestRate_ = interestRate_ * interval_ / uint256(365 days);
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
