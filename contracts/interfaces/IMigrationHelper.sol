// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

interface IMigrationHelper {

    /**************************************************************************************************************************************/
    /*** Events                                                                                                                         ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Set the pending admin of the contract.
     *  @param pendingAdmin_ The address of the admin to take ownership of the contract.
     */
    event PendingAdminSet(address indexed pendingAdmin_);

    /**
     *  @dev   Accept ownership.
     *  @param newOwner_ The new owner of the contract.
     */
    event OwnershipAccepted(address indexed newOwner_);

    /**
     *  @dev   Set the globals address.
     *  @param globals_ The globals address.
     */
    event GlobalsSet(address indexed globals_);

    /**
     *  @dev   Add loans to the TransitionLoanManager, seeding the accounting state.
     *  @param loanManager_ The address of the TransitionLoanManager contract.
     *  @param loan_        The address of the loan that was added to the TransitionLoanManager.
     */
    event LoanAddedToTransitionLoanManager(address indexed loanManager_, address indexed loan_);

    /**
     *  @dev   Transfer initial mint of PoolV2 tokens to all PoolV1 LPs.
     *  @param poolV1_ The address of the PoolV1 contract.
     *  @param poolV2_ The address of the PoolManager contract for V2.
     *  @param lp1_    Array of all LP addresses in
     *  @param lp2_    The address of the pool delegate to transfer ownership to.
     *  @param amount_ The amount of PoolV2 tokens that was transferred to each LP.
     */
    event TokensAirdropped(address indexed poolV1_, address indexed poolV2_, address lp1_, address indexed lp2_, uint256 amount_);

    /**
     *  @dev   Set pending lender of an outstanding loan to the TransitionLoanManager.
     *  @param loan_          The address of the loan contract.
     *  @param pendingLender_ The address of the LoanManager that is set as pending lender.
     */
    event PendingLenderSet(address indexed loan_, address indexed pendingLender_);

    /**
     *  @dev   Accept ownership as lender of an outstanding loan to the TransitionLoanManager.
     *  @param loan_          The address of the loan contract.
     *  @param pendingLender_ The address of the LoanManager that accepted ownership.
     */
    event LenderAccepted(address indexed loan_, address indexed pendingLender_);

    /**
     *  @dev   Upgrade the LoanManager away from the TransitionLoanManager.
     *  @param loanManager_  The address of the LoanManager.
     *  @param version_      The version to set the LoanManager to on upgrade.
     */
    event LoanManagerUpgraded(address indexed loanManager_, uint256 version_);

    /**
     *  @dev   Setting of the pending lender on loans has been rolled back.
     *  @param loans_ The array of addresses of loans affected by the rollback.
     */
    event RolledBackSetPendingLenders(address[] loans_);

    /**
     *  @dev   Taking ownership of loans has been rolled back.
     *  @param loans_       The array of addresses of loans affected by the rollback.
     *  @param debtLockers_ The array of addresses of debt lockers that have bee reset as respective lenders by the rollback.
     */
    event RolledBackTakeOwnershipOfLoans(address[] loans_, address[] debtLockers_);

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev The address of globals.
     */
    function globalsV2() external view returns (address globalsV2_);

    /**
     *  @dev The address of the pending admin.
     */
    function pendingAdmin() external view returns (address pendingAdmin_);

    /**
     *  @dev    Returns the previous lender of a given loan.
     *  @param  loan_           The address of the loan.
     *  @return previousLender_ The address of the previous lender.
     */
    function previousLenderOf(address loan_) external view returns (address previousLender_);

    /**************************************************************************************************************************************/
    /*** Admin Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev Accept ownership.
     */
    function acceptOwner() external;

    /**
     *  @dev   Set the pending admin of the contract.
     *  @param pendingAdmin_ The address of the admin to take ownership of the contract.
     */
    function setPendingAdmin(address pendingAdmin_) external;


    /**
     *  @dev   Set the globals address.
     *  @param globalsV2_ The address of the globals V2 contract.
     */
    function setGlobals(address globalsV2_) external;

    /**************************************************************************************************************************************/
    /*** Migration Functions                                                                                                            ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Add loans to the TransitionLoanManager, seeding the accounting state.
     *  @param poolV1_                The address of the PoolV1 contract.
     *  @param transitionLoanManager_ The address of the TransitionLoanManager contract.
     *  @param loans_                 Array of loans to add to the TransitionLoanManager.
     *  @param allowedDiff_           The allowed difference between the loan's principal and the sum of the loan's.
     */
    function addLoansToLoanManager(
        address poolV1_,
        address transitionLoanManager_,
        address[] calldata loans_,
        uint256 allowedDiff_
    ) external;

    /**
     *  @dev   Transfer initial mint of PoolV2 tokens to all PoolV1 LPs.
     *  @param poolV1Address_ The address of the PoolV1 contract.
     *  @param poolManager_   The address of the PoolManager contract for V2.
     *  @param lpsV1_         Array of all LP addresses in
     *  @param lpsV2_         The address of the pool delegate to transfer ownership to.
     *  @param allowedDiff_   The allowed difference between the sum of PoolV2 tokens that were transferred to each LP and the expected value of PoolV1.
     */
    function airdropTokens(
        address poolV1Address_,
        address poolManager_,
        address[] calldata lpsV1_,
        address[] calldata lpsV2_,
        uint256 allowedDiff_
    ) external;

    /**
     *  @dev   Set pending lender of all outstanding loans to the TransitionLoanManager.
     *  @param poolV1_                The address of the PoolV1 contract.
     *  @param poolV2ManagerAddress_  The address of the PoolManager contract for V2.
     *  @param loanFactoryAddress_    The address of the Loan factory contract.
     *  @param loans_                 Array of loans to add to transfer ownership on.
     *  @param allowedDiff_           The allowed difference between the loan's principal and the sum of the loan's.
     */
    function setPendingLenders(
        address poolV1_,
        address poolV2ManagerAddress_,
        address loanFactoryAddress_,
        address[] calldata loans_,
        uint256 allowedDiff_
    ) external;

    /**
     *  @dev   Accept ownership of all outstanding loans to the TransitionLoanManager.
     *  @param poolV1_                The address of the PoolV1 contract.
     *  @param transitionLoanManager_ The address of the TransitionLoanManager contract.
     *  @param loans_                 Array of loans to accept ownership on.
     *  @param allowedDiff_           The allowed difference between the loan's principal and the sum of the loan's.
     */
    function takeOwnershipOfLoans(
        address poolV1_,
        address transitionLoanManager_,
        address[] calldata loans_,
        uint256 allowedDiff_
    ) external;

    /**
     *  @dev   Upgrade the LoanManager from the TransitionLoanManager.
     *  @param transitionLoanManager_ The address of the TransitionLoanManager contract.
     *  @param version_               The version of the LoanManager to upgrade to.
     */
    function upgradeLoanManager(address transitionLoanManager_, uint256 version_) external;

    /**************************************************************************************************************************************/
    /*** Contingency Functions                                                                                                          ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Function to revert the step to set all the pending lenders, setting all to zero.
     *  @param loans_ Array of loans to set pending lender to zero on.
     */
    function rollback_setPendingLenders(address[] calldata loans_) external;

    /**
     *  @dev   Function to revert the step to take ownership, returning ownership of loans to previous lenders.
     *  @param transitionLoanManager_ The address of the TransitionLoanManager contract.
     *  @param loans_                 Array of loans to revert ownership of.
     */
    function rollback_takeOwnershipOfLoans(address transitionLoanManager_, address[] calldata loans_) external;

}
