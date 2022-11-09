// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { console } from "../../modules/contract-test-utils/contracts/log.sol";

import {
    IERC20Like,
    ILoanManagerLike,
    IMapleGlobalsLike,
    IMapleLoanLike,
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

    function checkTotalAssets(address poolManager_, address[] calldata loans_, uint256 loansAddedTimestamp) external view returns (uint256 expectedTotalAssets_, uint256 actualTotalAssets_) {
        uint256 totalPrincipal_;
        uint256 totalInterest_;

        for (uint256 i = 0; i < loans_.length; i++) {
            ( uint256 principal_, uint256 accruedInterest_ ) = _checkAssetsUnderManagement(poolManager_, loans_[i], loansAddedTimestamp);
            totalPrincipal_ += principal_;
            totalInterest_  += accruedInterest_;
        }

        uint256 cash_ = IERC20Like(IPoolManagerLike(poolManager_).asset()).balanceOf(IPoolManagerLike(poolManager_).pool());

        expectedTotalAssets_ = totalPrincipal_ + totalInterest_ + cash_;
        actualTotalAssets_   = IPoolManagerLike(poolManager_).totalAssets();
    }

    function _checkAssetsUnderManagement(address poolManager_, address loanAddress_, uint256 loansAddedTimestamp) internal view returns (uint256 principal, uint256 accruedInterest) {
        uint256 platformManagementFeeRate_ = IMapleGlobalsLike(globals).platformManagementFeeRate(poolManager_);
        uint256 delegateManagementFeeRate_ = IPoolManagerLike(poolManager_).delegateManagementFeeRate();
        uint256 managementFeeRate_         = platformManagementFeeRate_ + delegateManagementFeeRate_;

        // NOTE: If combined fee is greater than 100%, then cap delegate fee and clamp management fee.
        if (managementFeeRate_ > HUNDRED_PERCENT) {
            delegateManagementFeeRate_ = HUNDRED_PERCENT - platformManagementFeeRate_;
            managementFeeRate_         = HUNDRED_PERCENT;
        }

        IMapleLoanLike loan_ = IMapleLoanLike(loanAddress_);

        uint256 version_ = _getVersion(loanAddress_);

        uint256 interest_;

        if (version_ == 301 || version_ == 302) {
            ( , interest_, , )  = loan_.getNextPaymentBreakdown();
        } else if (version_ == 400) {
            ( , interest_, )  = IMapleLoanV4Like(loanAddress_).getNextPaymentBreakdown();
        }

        uint256 refinanceInterest = loan_.refinanceInterest();

        uint256  incomingNetInterest_ = _getNetInterest(interest_ - refinanceInterest, managementFeeRate_);
        uint256 netRefinanceInterest_ = _getNetInterest(refinanceInterest,             managementFeeRate_);

        uint256 nextPaymentDueDate_ = loan_.nextPaymentDueDate();

        uint256 startDate_ = nextPaymentDueDate_ - loan_.paymentInterval();

        if (loansAddedTimestamp < startDate_) {
            startDate_ = loansAddedTimestamp;
        }

        uint256 endDate_ = block.timestamp < nextPaymentDueDate_ ? block.timestamp : nextPaymentDueDate_;

        principal       = loan_.principal();
        accruedInterest = netRefinanceInterest_ + incomingNetInterest_ * (endDate_ - startDate_) / (nextPaymentDueDate_ - startDate_);
    }

    function _getNetInterest(uint256 interest_, uint256 feeRate_) internal pure returns (uint256 netInterest_) {
        netInterest_ = interest_ * (HUNDRED_PERCENT - feeRate_) / HUNDRED_PERCENT;
    }

    function _getVersion(address loan_) internal view returns (uint256 version_) {
        version_ = IMapleProxyFactoryLike(IMapleLoanLike(loan_).factory()).versionOf(IMapleLoanLike(loan_).implementation());
    }

}
