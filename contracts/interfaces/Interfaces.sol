// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

interface IDebtLockerLike {

    function acceptLender() external;

    function loan() external view returns (address loan_);

    function pool() external view returns (address pool_);

    function poolDelegate() external view returns (address poolDelegate_);

    function setPendingLender(address newLender_) external;
}

interface IERC20Like {

    function approve(address account_, uint256 amount) external returns (bool success_);

    function balanceOf(address account_) external view returns(uint256 balance_);

    function decimals() external view returns (uint8 decimals_);

    function transfer(address to_, uint256 amount) external returns (bool success_);

}

interface ILoanFactoryLike {

    function isLoan(address loan_) external view returns (bool isLoan_);

    function defaultVersion() external view returns (uint256 defaultVersion_);

    function implementationOf(uint256 version_) external view returns (address implementation_);

}

interface ILoanManagerLike {

    function accountedInterest() external view returns (uint256);

    function domainEnd() external view returns (uint256);

    function domainStart() external view returns (uint256);

    function getAccruedInterest() external view returns (uint256);

    function issuanceRate() external view returns (uint256);

    function paymentIdOf(address loan_) external view returns (uint24 paymentId_);

    function payments(uint256 paymentId_) external view returns (
        uint24  platformManagementFeeRate,
        uint24  delegateManagementFeeRate,
        uint48  startDate,
        uint48  paymentDueDate,
        uint128 incomingNetInterest,
        uint128 refinanceInterest,
        uint256 issuanceRate
    );

}

interface IMapleGlobalsLike {

    function isFactory(bytes32 factoryType_, address factory_) external view returns (bool valid_);

    function poolDelegates(address poolDelegate_) external view returns (address ownedPoolManager_, bool isPoolDelegate_);

    function delegateManagementFeeRate(address poolManager_) external view returns (uint256 delegateManagementFeeRate_);

    function platformManagementFeeRate(address poolManager_) external view returns (uint256 platformManagementFeeRate_);

    function protocolPaused() external view returns (bool paused_);

}

interface IMapleProxiedLike {

    function factory() external view returns (address factory_);

}

interface IMapleProxyFactoryLike {

    function isInstance(address instance_) external view returns (bool isInstance_);

    function versionOf(address instance_) external view returns (uint256 version_);

}

interface IMapleLoanLike is IMapleProxiedLike {

    function borrower() external view returns (address borrower_);

    function claimableFunds() external view returns (uint256 claimableFunds_);

    function closeLoan(uint256 amount_) external returns (uint256 principal_, uint256 interest_);

    function drawableFunds() external view returns (uint256 drawableFunds_);

    function getClosingPaymentBreakdown() external view returns (uint256 principal_, uint256 interest_, uint256 fees_);

    function getNextPaymentBreakdown()
        external view returns (uint256 principal_, uint256 interest_, uint256 delegateFee_, uint256 platformFee_);

    function implementation() external view returns (address implementation_);

    function interestRate() external view returns (uint256 interestRate_);

    function lateFeeRate() external view returns (uint256 lateFeeRate_);

    function lateInterestPremium() external view returns (uint256 lateInterestPremium_);

    function lender() external view returns (address lender_);

    function makePayment(uint256 amount_) external returns (uint256 principal_, uint256 interest_);

    function nextPaymentDueDate() external view returns (uint256 nextPaymentDueDate_);

    function paymentInterval() external view returns (uint256 paymentInterval_);

    function pendingLender() external view returns (address pendingLender_);

    function principal() external view returns (uint256 principal_);

    function refinanceInterest() external view returns (uint256 refinanceInterest_);

    function upgrade(uint256 toVersion_, bytes calldata arguments_) external;

}

interface IMapleLoanV4Like {

    function getNextPaymentBreakdown() external view returns (uint256 principal_, uint256 interest_, uint256 fees_);

    function getNextPaymentDetailedBreakdown()
        external view returns (uint256 principal_, uint256[3] memory interest_, uint256[2] memory fees_);

}

interface IPoolManagerLike is IMapleProxiedLike {

    function active() external view returns (bool active_);

    function asset() external view returns (address asset_);

    function delegateManagementFeeRate() external view returns (uint256 delegateManagementFeeRate_);

    function loanManagerList(uint256 index_) external view returns (address loanManager_);

    function pool() external view returns (address pool_);

    function poolDelegate() external view returns (address poolDelegate_);

    function totalAssets() external view returns (uint256 totalAssets_);

}

interface IPoolV1Like {

    function balanceOf(address account_) external view returns (uint256 balance_);

    function interestSum() external view returns (uint256 interestSum_);

    function liquidityAsset() external view returns (address liquidityAsset_);

    function poolLosses() external view returns (uint256 poolLosses_);

    function principalOut() external view returns (uint256 principalOut_);

    function recognizableLossesOf(address account_) external view returns (uint256 recognizableLosses_);

    function totalSupply() external view returns (uint256 totalSupply_);

    function withdrawableFundsOf(address account_) external view returns (uint256 withdrawableFunds_);

}

interface ITransitionLoanManagerLike {

    function add(address loan_) external;

    function setOwnershipTo(address[] calldata loans_, address[] calldata newLenders_) external;

    function takeOwnership(address[] calldata loans_) external;

    function upgrade(uint256 toVersion_, bytes calldata arguments_) external;

}
