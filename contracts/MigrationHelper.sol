// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ERC20Helper }           from "../modules/erc20-helper/src/ERC20Helper.sol";
import { NonTransparentProxied } from "../modules/non-transparent-proxy/contracts/NonTransparentProxied.sol";

import {
    IDebtLockerLike,
    IERC20Like,
    ILoanFactoryLike,
    IMapleGlobalsLike,
    IMapleLoanLike,
    IMapleProxiedLike,
    IMapleProxyFactoryLike,
    IPoolManagerLike,
    IPoolV1Like,
    ITransitionLoanManagerLike
} from "./interfaces/Interfaces.sol";

import { IMigrationHelper } from "./interfaces/IMigrationHelper.sol";

contract MigrationHelper is IMigrationHelper, NonTransparentProxied {

    address public override globalsV2;
    address public override pendingAdmin;

    mapping(address => address) public override previousLenderOf;

    /******************************************************************************************************************************/
    /*** Modifiers                                                                                                              ***/
    /******************************************************************************************************************************/

    modifier onlyAdmin() {
        require(msg.sender == admin(), "MH:ONLY_ADMIN");
        _;
    }

    /******************************************************************************************************************************/
    /*** Admin Functions                                                                                                        ***/
    /******************************************************************************************************************************/

    function setPendingAdmin(address pendingAdmin_) external override onlyAdmin {
        emit PendingAdminSet(pendingAdmin = pendingAdmin_);
    }

    function acceptOwner() external override {
        require(msg.sender == pendingAdmin, "MH:AO:NO_AUTH");

        _setAddress(ADMIN_SLOT, msg.sender);

        pendingAdmin = address(0);

        emit OwnershipAccepted(msg.sender);
    }

    function setGlobals(address globalsV2_) external override onlyAdmin {
        emit GlobalsSet(globalsV2 = globalsV2_);
    }

    /******************************************************************************************************************************/
    /*** Step 1: Add Loans to TransitionLoanManager accounting (No contingency needed) [Phase 7]                                ***/
    /******************************************************************************************************************************/

    function addLoansToLoanManager(address transitionLoanManager_, address[] calldata loans_) external override onlyAdmin {
        IMapleGlobalsLike globalsV2_ = IMapleGlobalsLike(globalsV2);

        // Check the protocol is not paused.
        require(!globalsV2_.protocolPaused(), "MH:ALTLM:PROTOCOL_PAUSED");

        // Check the TransitionLoanManager is valid.
        address loanManagerFactory_ = IMapleProxiedLike(transitionLoanManager_).factory();

        require(IMapleProxyFactoryLike(loanManagerFactory_).isInstance(transitionLoanManager_), "MH:ALTLM:INVALID_LM");
        require(globalsV2_.isFactory("LOAN_MANAGER", loanManagerFactory_),                      "MH:ALTLM:INVALID_LM_FACTORY");

        for (uint256 i; i < loans_.length; ++i) {
            address loan_ = loans_[i];
            require(IMapleLoanLike(loan_).claimableFunds() == 0, "MH:ALTLM:CLAIMABLE_FUNDS");
            ITransitionLoanManagerLike(transitionLoanManager_).add(loan_);
            emit LoanAddedToTransitionLoanManager(transitionLoanManager_, loan_);
        }
    }

    /******************************************************************************************************************************/
    /*** Step 2: Airdrop tokens to all new LPs (No contingency needed) [Phase 10]                                               ***/
    /******************************************************************************************************************************/

    function airdropTokens(address poolV1Address_, address poolManager_, address[] calldata lpsV1_, address[] calldata lpsV2_, uint256 allowedDiff_) external override onlyAdmin {
        IPoolV1Like poolV1_ = IPoolV1Like(poolV1Address_);

        uint256 decimalConversionFactor_ = 10 ** IERC20Like(poolV1_.liquidityAsset()).decimals();
        uint256 totalLosses_             = poolV1_.poolLosses();
        address poolV2_                  = IPoolManagerLike(poolManager_).pool();

        uint256 totalPoolV1Value_ = ((poolV1_.totalSupply() * decimalConversionFactor_) / 1e18) + poolV1_.interestSum() - poolV1_.poolLosses();  // Add interfaces

        uint256 totalValueTransferred_;

        for (uint256 i = 0; i < lpsV1_.length; ++i) {
            address lpV1_ = lpsV1_[i];
            address lpV2_ = lpsV2_[i];

            uint256 lpLosses_ = totalLosses_ > 0 ? poolV1_.recognizableLossesOf(lpV1_) : 0;

            uint256 poolV2LPBalance_ = poolV1_.balanceOf(lpV1_) * decimalConversionFactor_ / 1e18 + poolV1_.withdrawableFundsOf(lpV1_) - lpLosses_;

            totalValueTransferred_ += poolV2LPBalance_;

            require(ERC20Helper.transfer(poolV2_, lpV2_, poolV2LPBalance_), "MH:AT:LP_TRANSFER_FAILED");

            emit TokensAirdropped(address(poolV1_), poolV2_, lpV1_, lpV2_, poolV2LPBalance_);
        }

        uint256 absError_ = totalPoolV1Value_ > totalValueTransferred_ ? totalPoolV1Value_ - totalValueTransferred_ : totalValueTransferred_ - totalPoolV1Value_;
        require(absError_ <= allowedDiff_, "MH:AT:VALUE_MISMATCH");

        uint256 dust_ = IERC20Like(address(poolV2_)).balanceOf(address(this));

        require(dust_ == 0 || ERC20Helper.transfer(poolV2_, lpsV2_[0], dust_), "MH:AT:PD_TRANSFER_FAILED");
    }

    /******************************************************************************************************************************/
    /*** Step 3: Set pending lender ownership for all loans to new LoanManager (Contingency needed) [Phase 12-13]               ***/
    /******************************************************************************************************************************/

    function setPendingLenders(address poolV1_, address poolV2ManagerAddress_, address loanFactoryAddress_, address[] calldata loans_) external override onlyAdmin {
        IMapleGlobalsLike globalsV2_ = IMapleGlobalsLike(globalsV2);

        // Check the protocol is not paused.
        require(!globalsV2_.protocolPaused(), "MH:SPL:PROTOCOL_PAUSED");

        // Check the PoolManager is valid (avoid stack too deep).
        {
            address poolManagerFactory_ = IPoolManagerLike(poolV2ManagerAddress_).factory();

            require(IMapleProxyFactoryLike(poolManagerFactory_).isInstance(poolV2ManagerAddress_), "MH:SPL:INVALID_PM");
            require(IMapleGlobalsLike(globalsV2).isFactory("POOL_MANAGER", poolManagerFactory_),   "MH:SPL:INVALID_PM_FACTORY");
        }

        address transitionLoanManager_ = IPoolManagerLike(poolV2ManagerAddress_).loanManagerList(0);

        // Check the TransitionLoanManager is valid (avoid stack too deep).
        {
            address loanManagerFactory_ = IMapleProxiedLike(transitionLoanManager_).factory();

            require(IMapleProxyFactoryLike(loanManagerFactory_).isInstance(transitionLoanManager_), "MH:SPL:INVALID_LM");
            require(IMapleGlobalsLike(globalsV2).isFactory("LOAN_MANAGER", loanManagerFactory_),    "MH:SPL:INVALID_LM_FACTORY");
        }

        // Check the Pool is active and owned by a valid PD (avoid stack too deep).
        {
            (
                address ownedPoolManager_,
                bool isPoolDelegate_
            ) = IMapleGlobalsLike(globalsV2).poolDelegates(IPoolManagerLike(poolV2ManagerAddress_).poolDelegate());

            require(IPoolManagerLike(poolV2ManagerAddress_).active(), "MH:SPL:PM_NOT_ACTIVE");
            require(ownedPoolManager_ == poolV2ManagerAddress_,       "MH:SPL:NOT_OWNED_PM");
            require(isPoolDelegate_,                                  "MH:SPL:INVALID_PD");
        }

        require(IMapleGlobalsLike(globalsV2).isFactory("LOAN", loanFactoryAddress_), "MH:SPL:INVALID_LOAN_FACTORY");

        for (uint256 i; i < loans_.length; ++i) {
            IMapleLoanLike  loan_       = IMapleLoanLike(loans_[i]);
            IDebtLockerLike debtLocker_ = IDebtLockerLike(loan_.lender());

            // Validate the PoolV1 address.
            require(debtLocker_.pool() == poolV1_, "MH:SPL:INVALID_DL_POOL");

            // Validate the loan.
            require(ILoanFactoryLike(loanFactoryAddress_).isLoan(address(loan_)), "MH:SPL:INVALID_LOAN");

            // Begin transfer of loan to the TransitionLoanManager.
            debtLocker_.setPendingLender(transitionLoanManager_);

            require(loan_.pendingLender() == transitionLoanManager_, "MH:SPL:INVALID_PENDING_LENDER");

            emit PendingLenderSet(address(loan_), transitionLoanManager_);
        }
    }

    /******************************************************************************************************************************/
    /*** Step 4: Take ownership of all loans (Contingency needed) [Phase 14-15]                                                 ***/
    /******************************************************************************************************************************/

    function takeOwnershipOfLoans(address transitionLoanManager_, address[] calldata loans_) external override onlyAdmin {
        IMapleGlobalsLike globalsV2_ = IMapleGlobalsLike(globalsV2);

        // Check the protocol is not paused.
        require(!globalsV2_.protocolPaused(), "MH:TOOL:PROTOCOL_PAUSED");

        // Check the TransitionLoanManager is valid.
        address loanManagerFactory_ = IMapleProxiedLike(transitionLoanManager_).factory();

        require(IMapleProxyFactoryLike(loanManagerFactory_).isInstance(transitionLoanManager_), "MH:TOOL:INVALID_LM");
        require(globalsV2_.isFactory("LOAN_MANAGER", loanManagerFactory_),                      "MH:TOOL:INVALID_LM_FACTORY");

        for (uint256 i; i < loans_.length; ++i) {
            address loan_ = loans_[i];
            previousLenderOf[loan_] = IMapleLoanLike(loan_).lender();
        }

        ITransitionLoanManagerLike(transitionLoanManager_).takeOwnership(loans_);

        for (uint256 i; i < loans_.length; ++i) {
            address loan_ = loans_[i];
            require(IMapleLoanLike(loan_).lender() == transitionLoanManager_, "MH:TOOL:INVALID_LENDER");
            emit LenderAccepted(loan_, transitionLoanManager_);
        }
    }

    /******************************************************************************************************************************/
    /*** Step 5: Upgrade Loan Manager (Contingency needed) [Phase 16]                                                           ***/
    /******************************************************************************************************************************/

    function upgradeLoanManager(address transitionLoanManager_, uint256 version_) public override onlyAdmin {
        IMapleGlobalsLike globalsV2_ = IMapleGlobalsLike(globalsV2);

        // Check the protocol is not paused.
        require(!globalsV2_.protocolPaused(), "MH:ULM:PROTOCOL_PAUSED");

        // Check the TransitionLoanManager is valid.
        address loanManagerFactory_ = IMapleProxiedLike(transitionLoanManager_).factory();
        require(IMapleProxyFactoryLike(loanManagerFactory_).isInstance(transitionLoanManager_), "MH:ULM:INVALID_LM");
        require(globalsV2_.isFactory("LOAN_MANAGER", loanManagerFactory_),                      "MH:ULM:INVALID_LM_FACTORY");

        ITransitionLoanManagerLike(transitionLoanManager_).upgrade(version_, "");

        emit LoanManagerUpgraded(transitionLoanManager_, version_);
    }

    /******************************************************************************************************************************/
    /*** Contingency Functions                                                                                                  ***/
    /******************************************************************************************************************************/

    // Rollback Step 3 [Phase 12-13]
    function rollback_setPendingLenders(address[] calldata loans_) external override onlyAdmin {
        for (uint256 i; i < loans_.length; ++i) {
            IDebtLockerLike(
                IMapleLoanLike(loans_[i]).lender()
            ).setPendingLender(address(0));
        }

        emit RolledBackSetPendingLenders(loans_);
    }

    // Rollback Step 4 [Phase 14-15]
    function rollback_takeOwnershipOfLoans(address transitionLoanManager_, address[] calldata loans_) external override onlyAdmin {
        address[] memory debtLockers_ = new address[](loans_.length);

        for (uint256 i; i < loans_.length; ++i) {
            address loan_ = loans_[i];
            debtLockers_[i] = previousLenderOf[loan_];
            delete previousLenderOf[loan_];
        }

        ITransitionLoanManagerLike(transitionLoanManager_).setOwnershipTo(loans_, debtLockers_);

        for (uint256 i; i < debtLockers_.length; ++i) {
            IDebtLockerLike(debtLockers_[i]).acceptLender();
        }

        emit RolledBackTakeOwnershipOfLoans(loans_, debtLockers_);
    }

    /******************************************************************************************************************************/
    /*** Helper Functions                                                                                                       ***/
    /******************************************************************************************************************************/

    function _setAddress(bytes32 slot_, address value_) private {
        assembly {
            sstore(slot_, value_)
        }
    }

}
