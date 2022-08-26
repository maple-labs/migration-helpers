// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

interface IDebtLockerLike {

    function poolDelegate() external view returns (address poolDelegate_);

    function setPendingLender(address newLender_) external;
}

interface IERC20Like {

    function approve(address account_, uint256 amount) external returns (bool success_);

    function balanceOf(address account_) external view returns(uint256);

    function transfer(address to_, uint256 amount) external returns (bool success_);

}

interface IGlobalsLike {

    function platformManagementFeeRate(address poolManager_) external view returns (uint256 platformManagementFeeRate_);

}

interface IMapleLoanLike {

    function borrower() external view returns (address borrower_);

    function claimableFunds() external view returns (uint256 claimableFunds_);

    function closeLoan(uint256 amount_) external returns (uint256 principal_, uint256 interest_);

    function drawableFunds() external view returns (uint256 drawableFunds_);

    function getClosingPaymentBreakdown() external view returns (uint256 principal_, uint256 interest_, uint256 fees_);

    function getNextPaymentBreakdown() external view returns (uint256 principal_, uint256 interest_);

    function implementation() external view returns (address implementation_);

    function lender() external view returns (address lender_);

    function makePayment(uint256 amount_) external returns (uint256 principal_, uint256 interest_);

    function nextPaymentDueDate() external view returns (uint256 nextPaymentDueDate_);

    function paymentInterval() external view returns (uint256 paymentInterval_);

    function pendingLender() external view returns (address pendingLender_);

    function principal() external view returns (uint256 principal_);

    function upgrade(uint256 toVersion_, bytes calldata arguments_) external;

}

interface IPoolManagerLike {

    function asset() external view returns (address asset_);

    function delegateManagementFeeRate() external view returns (uint256 delegateManagementFeeRate_);

    function pool() external view returns (address pool_);

    function totalAssets() external view returns (uint256 totalAssets_);

}
