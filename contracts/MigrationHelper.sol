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
        pendingAdmin = pendingAdmin_;
        emit PendingAdminSet(pendingAdmin_);
    }

    function acceptOwner() external override {
        require(msg.sender == pendingAdmin, "MH:AO:NO_AUTH");

        _setAddress(ADMIN_SLOT, msg.sender);

        pendingAdmin = address(0);

        emit OwnershipAccepted(msg.sender);
    }

    function setGlobals(address globalsV2_) external override onlyAdmin {
        globalsV2 = globalsV2_;

        emit GlobalsSet(globalsV2_);
    }

    /******************************************************************************************************************************/
    /*** Step 1: Add Loans to TransitionLoanManager accounting                                                                  ***/
    /******************************************************************************************************************************/

    function addLoansToLM(address transitionLoanManager_, address[] calldata loans_) external override onlyAdmin {
        IMapleGlobalsLike globalsV2_ = IMapleGlobalsLike(globalsV2);

        // Check the protocol is not paused.
        require(!globalsV2_.protocolPaused(), "MH:ALTLM:PROTOCOL_PAUSED");

        // Check the TransitionLoanManager is valid.
        address loanManagerFactory_ = IMapleProxiedLike(transitionLoanManager_).factory();
        require(IMapleProxyFactoryLike(loanManagerFactory_).isInstance(transitionLoanManager_), "MH:ALTLM:INVALID_LM");
        require(globalsV2_.isFactory("LOAN_MANAGER", loanManagerFactory_),                      "MH:ALTLM:INVALID_LM_FACTORY");

        for (uint256 i; i < loans_.length; ++i) {
            require(IMapleLoanLike(loans_[i]).claimableFunds() == 0, "MH:ALTLM:CLAIMABLE_FUNDS");
            ITransitionLoanManagerLike(transitionLoanManager_).add(loans_[i]);
            emit LoanAddedToTransitionLoanManager(transitionLoanManager_, loans_[i]);
        }
    }

    /******************************************************************************************************************************/
    /*** Step 2: Airdrop tokens to all new LPs                                                                                  ***/
    /******************************************************************************************************************************/

    function airdropTokens(address poolV1Address_, address poolManager_, address[] calldata lpsV1_, address[] calldata lpsV2_, uint256 allowedDiff_) external override onlyAdmin {
        IPoolV1Like poolV1_ = IPoolV1Like(poolV1Address_);

        uint256 decimalConversionFactor_ = 10 ** IERC20Like(poolV1_.liquidityAsset()).decimals();

        uint256 totalLosses_ = poolV1_.poolLosses();
        address poolV2_      = IPoolManagerLike(poolManager_).pool();

        uint256 totalPoolV1Value_ = poolV1_.totalSupply() * decimalConversionFactor_ / 1e18 + poolV1_.interestSum() - poolV1_.poolLosses();  // Add interfaces

        uint256 totalValueTransferred_;

        for (uint256 i = 0; i < lpsV1_.length; ++i) {
            address lpV1_ = lpsV1_[i];
            address lpV2_ = lpsV2_[i];

            uint256 lpLosses_ = totalLosses_ > 0 ? poolV1_.recognizableLossesOf(lpV1_) : 0;

            uint256 poolV2LPBalance_ = poolV1_.balanceOf(lpV1_) * decimalConversionFactor_ / 1e18 + poolV1_.withdrawableFundsOf(lpV1_) - lpLosses_;

            totalValueTransferred_ += poolV2LPBalance_;

            require(ERC20Helper.transfer(poolV2_, lpV2_, poolV2LPBalance_), "MH:AT:TRANSFER_FAILED");

            emit TokensAirdropped(address(poolV1_), poolV2_, lpV1_, lpV2_, poolV2LPBalance_);
        }

        uint256 absError = totalPoolV1Value_  > totalValueTransferred_ ? totalPoolV1Value_ - totalValueTransferred_ : totalValueTransferred_ - totalPoolV1Value_;
        require(absError <= allowedDiff_, "MH:AT:VALUE_MISMATCH");
    }

    /******************************************************************************************************************************/
    /*** Step 3: Set pending lender ownership for all loans to new LoanManager                                                  ***/
    /******************************************************************************************************************************/

    function setPendingLenders(
        address poolV1_,
        address poolV2ManagerAddress_,
        address loanFactoryAddress_,
        address[] calldata loans_
    )
        external override onlyAdmin
    {
        IMapleGlobalsLike globalsV2_     = IMapleGlobalsLike(globalsV2);
        IPoolManagerLike  poolV2Manager_ = IPoolManagerLike(poolV2ManagerAddress_);

        // Check the protocol is not paused.
        require(!globalsV2_.protocolPaused(), "MH:SPL:PROTOCOL_PAUSED");

        // Check the PoolManager is valid (avoid stack too deep).
        {
            address poolManagerFactory_ = poolV2Manager_.factory();
            require(IMapleProxyFactoryLike(poolManagerFactory_).isInstance(poolV2ManagerAddress_), "MH:SPL:INVALID_PM");
            require(globalsV2_.isFactory("POOL_MANAGER", poolManagerFactory_),                     "MH:SPL:INVALID_PM_FACTORY");
        }

        address transitionLoanManager_ = poolV2Manager_.loanManagerList(0);

        // Check the TransitionLoanManager is valid (avoid stack too deep).
        {
            address loanManagerFactory_ = IMapleProxiedLike(transitionLoanManager_).factory();
            require(IMapleProxyFactoryLike(loanManagerFactory_).isInstance(transitionLoanManager_), "MH:SPL:INVALID_LM");
            require(globalsV2_.isFactory("LOAN_MANAGER", loanManagerFactory_),                      "MH:SPL:INVALID_LM_FACTORY");
        }

        // Check the Pool is active and owned by a valid PD (avoid stack too deep).
        {
            ( address ownedPoolManager_, bool isPoolDelegate_ ) = globalsV2_.poolDelegates(poolV2Manager_.poolDelegate());
            require(poolV2Manager_.active(),                    "MH:SPL:PM_NOT_ACTIVE");
            require(ownedPoolManager_ == poolV2ManagerAddress_, "MH:SPL:NOT_OWNED_PM");
            require(isPoolDelegate_,                            "MH:SPL:INVALID_PD");
        }

        ILoanFactoryLike loanFactory_ = ILoanFactoryLike(loanFactoryAddress_);

        require(globalsV2_.isFactory("LOAN", loanFactoryAddress_), "MH:SPL:INVALID_LOAN_FACTORY");

        for (uint256 i; i < loans_.length; ++i) {
            IMapleLoanLike  loan_       = IMapleLoanLike(loans_[i]);
            IDebtLockerLike debtLocker_ = IDebtLockerLike(loan_.lender());

            // Validate the PoolV1 address.
            require(debtLocker_.pool() == poolV1_, "MH:SPL:INVALID_DL_POOL");

            // Validate the loan.
            require(loanFactory_.isLoan(address(loan_)), "MH:SPL:INVALID_LOAN");

            // Transfer loan ownership
            debtLocker_.setPendingLender(transitionLoanManager_);

            // Transfer loan to the TransitionLoanManager.
            require(loan_.pendingLender() == transitionLoanManager_, "MH:SPL:INVALID_PENDING_LENDER");

            emit PendingLenderSet(address(loan_), transitionLoanManager_);
        }
    }

    /******************************************************************************************************************************/
    /*** Step 4: Take ownership of all loans                                                                                    ***/
    /******************************************************************************************************************************/

    function takeOwnershipOfLoans(address transitionLoanManager_, address[] calldata loans_) external override onlyAdmin {
        IMapleGlobalsLike globalsV2_ = IMapleGlobalsLike(globalsV2);

        // Check the protocol is not paused.
        require(!globalsV2_.protocolPaused(), "MH:TOOL:PROTOCOL_PAUSED");

        // Check the TransitionLoanManager is valid.
        address loanManagerFactory_ = IMapleProxiedLike(transitionLoanManager_).factory();
        require(IMapleProxyFactoryLike(loanManagerFactory_).isInstance(transitionLoanManager_), "MH:TOOL:INVALID_LM");
        require(globalsV2_.isFactory("LOAN_MANAGER", loanManagerFactory_),                      "MH:TOOL:INVALID_LM_FACTORY");

        ITransitionLoanManagerLike(transitionLoanManager_).takeOwnership(loans_);

        for (uint256 i; i < loans_.length; ++i) {
            require(IMapleLoanLike(loans_[i]).lender() == transitionLoanManager_, "MH:TOOL:INVALID_LENDER");
            emit LenderAccepted(loans_[i], transitionLoanManager_);
        }
    }

    /******************************************************************************************************************************/
    /*** Step 5: Upgrade Loans                                                                                                  ***/
    /******************************************************************************************************************************/

    function upgradeLoanManager(address transitionLoanManager_, uint256 version_) external override onlyAdmin {
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
    /*** Helper Functions                                                                                                       ***/
    /******************************************************************************************************************************/

    function _setAddress(bytes32 slot_, address value_) private {
        assembly {
            sstore(slot_, value_)
        }
    }

}
