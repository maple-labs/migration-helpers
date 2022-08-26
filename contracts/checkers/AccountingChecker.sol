// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { console } from "../../modules/contract-test-utils/contracts/log.sol";

import { IERC20Like, IGlobalsLike, IMapleLoanLike, IPoolManagerLike } from "../interfaces/Interfaces.sol";

contract AccountingChecker {

    uint256 constant PRECISION  = 1e30;
    uint256 constant SCALED_ONE = 1e18;

    address public globals;

    constructor (address globals_) {
        globals = globals_;
    }

    function checkTotalAssets(address poolManager_, address[] calldata loans_) external view returns (uint256 expectedTotalAssets_, uint256 actualTotalAssets_) {
        uint256 totalPrincipal_;
        uint256 totalInterest_;
        for (uint256 i = 0; i < loans_.length; i++) {
            ( uint256 principal_, uint256 accruedInterest_ ) = _checkAssetsUnderManagement(poolManager_, loans_[i]);
            totalPrincipal_ += principal_;
            totalInterest_  += accruedInterest_;
        }

        uint256 cash_ = IERC20Like(IPoolManagerLike(poolManager_).asset()).balanceOf(IPoolManagerLike(poolManager_).pool());

        expectedTotalAssets_ = totalPrincipal_ + totalInterest_ + cash_;
        actualTotalAssets_   = IPoolManagerLike(poolManager_).totalAssets();
    }

    function _checkAssetsUnderManagement(address poolManager_, address loan_) internal view returns (uint256 principal, uint256 accruedInterest) {
        uint256 platformManagementFeeRate_ = IGlobalsLike(globals).platformManagementFeeRate(poolManager_);
        uint256 delegateManagementFeeRate_ = IPoolManagerLike(poolManager_).delegateManagementFeeRate();
        uint256 managementFeeRate_         = platformManagementFeeRate_ + delegateManagementFeeRate_;

        // TODO: Change name
        ( , uint256 incomingNetInterest_ ) = IMapleLoanLike(loan_).getNextPaymentBreakdown();

        // Interest used for issuance rate calculation is:
        incomingNetInterest_ = (incomingNetInterest_ * (SCALED_ONE - managementFeeRate_) / SCALED_ONE);

        uint256 interval_  = IMapleLoanLike(loan_).paymentInterval();
        uint256 startDate_ = IMapleLoanLike(loan_).nextPaymentDueDate() - interval_;

        principal = IMapleLoanLike(loan_).principal();

        // TODO: Add max for delta to be interval
        accruedInterest = (block.timestamp - startDate_) * incomingNetInterest_ / interval_;
    }

}
