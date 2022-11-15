// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { Address, console, TestUtils } from "../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 }                   from "../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { NonTransparentProxy }         from "../modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

import { MigrationHelper } from "../contracts/MigrationHelper.sol";

import {
    MockDebtLocker,
    MockGlobals,
    MockLoan,
    MockLoanManager,
    MockLoanFactory,
    MockPoolV1,
    MockPoolV2Manager,
    MockProxyFactory
} from "./Mocks.sol";

contract MigrationHelperTestBase is TestUtils {

    address migrationHelperImplementation;

    address loanImplementation = address(new Address());
    address poolV1             = address(new Address());
    address owner              = address(new Address());
    address poolDelegate       = address(new Address());

    MockDebtLocker    debtLocker1        = new MockDebtLocker();
    MockDebtLocker    debtLocker2        = new MockDebtLocker();
    MockGlobals       globals            = new MockGlobals();
    MockLoan          loan1              = new MockLoan();
    MockLoan          loan2              = new MockLoan();
    MockLoanManager   loanManager        = new MockLoanManager();
    MockLoanFactory   loanFactory        = new MockLoanFactory();
    MockPoolV2Manager poolV2Manager      = new MockPoolV2Manager();
    MockProxyFactory  loanManagerFactory = new MockProxyFactory();
    MockProxyFactory  poolManagerFactory = new MockProxyFactory();

    MigrationHelper migrationHelper;

    function setUp() external {
        debtLocker1.__setLoan(address(loan1));
        debtLocker2.__setLoan(address(loan2));

        debtLocker1.__setPool(address(poolV1));
        debtLocker2.__setPool(address(poolV1));

        globals.__setIsPoolDelegate(address(poolDelegate), true);
        globals.__setOwnedPoolManager(address(poolDelegate), address(poolV2Manager));
        globals.__setProtocolPaused(false);
        globals.__setValidFactory("POOL_MANAGER", address(poolManagerFactory), true);
        globals.__setValidFactory("LOAN_MANAGER", address(loanManagerFactory), true);
        globals.__setValidFactory("LOAN",         address(loanFactory),        true);

        loan1.__setImplementation(loanImplementation);
        loan2.__setImplementation(loanImplementation);

        loan1.__setLender(address(debtLocker1));
        loan2.__setLender(address(debtLocker2));

        loanFactory.__setDefaultVersion(400);
        loanFactory.__setImplementation(400, loanImplementation);
        loanFactory.__setIsLoan(address(loan1), true);
        loanFactory.__setIsLoan(address(loan2), true);

        loanManager.__setFactory(address(loanManagerFactory));

        loanManagerFactory.__setIsInstance(address(loanManager), true);

        poolV2Manager.__setActive(true);
        poolV2Manager.__setFactory(address(poolManagerFactory));
        poolV2Manager.__setLoanManager(address(loanManager));
        poolV2Manager.__setPoolDelegate(address(poolDelegate));

        poolManagerFactory.__setIsInstance(address(poolV2Manager), true);

        migrationHelperImplementation = address(new MigrationHelper());

        migrationHelper = MigrationHelper(address(new NonTransparentProxy(owner, migrationHelperImplementation)));

        vm.prank(owner);
        migrationHelper.setGlobals(address(globals));

        loan1.__setNextPaymentDueDate(block.timestamp + 30 days);
        loan2.__setNextPaymentDueDate(block.timestamp + 30 days);
    }
}

contract SetPendingLendersTests is MigrationHelperTestBase {

    function _callSetPendingLenders() internal {
        address[] memory loans = new address[](2);
        loans[0] = address(loan1);
        loans[1] = address(loan2);

        vm.prank(owner);
        migrationHelper.setPendingLenders(address(poolV1), address(poolV2Manager), address(loanFactory), loans);
    }

    function test_setPendingLenders_notAdmin() external {
        address[] memory loans = new address[](2);
        loans[0] = address(loan1);
        loans[1] = address(loan2);

        vm.expectRevert("MH:ONLY_ADMIN");
        migrationHelper.setPendingLenders(address(poolV1), address(poolV2Manager), address(loanFactory), loans);

        _callSetPendingLenders();
    }

    function test_setPendingLenders_protocolPaused() external {
        globals.__setProtocolPaused(true);

        vm.expectRevert("MH:SPL:PROTOCOL_PAUSED");
        _callSetPendingLenders();

        globals.__setProtocolPaused(false);

        _callSetPendingLenders();
    }

    function test_setPendingLenders_invalidPoolManager() external {
        poolManagerFactory.__setIsInstance(address(poolV2Manager), false);

        vm.expectRevert("MH:SPL:INVALID_PM");
        _callSetPendingLenders();

        poolManagerFactory.__setIsInstance(address(poolV2Manager), true);

        _callSetPendingLenders();
    }

    function test_setPendingLenders_invalidPMFactory() external {
        globals.__setValidFactory("POOL_MANAGER", address(poolManagerFactory), false);

        vm.expectRevert("MH:SPL:INVALID_PM_FACTORY");
        _callSetPendingLenders();

        globals.__setValidFactory("POOL_MANAGER", address(poolManagerFactory), true);

        _callSetPendingLenders();
    }

    function test_setPendingLenders_invalidLoanManager() external {
        loanManagerFactory.__setIsInstance(address(loanManager), false);

        vm.expectRevert("MH:SPL:INVALID_LM");
        _callSetPendingLenders();

        loanManagerFactory.__setIsInstance(address(loanManager), true);

        _callSetPendingLenders();
    }

    function test_setPendingLenders_invalidLMFactory() external {
        globals.__setValidFactory("LOAN_MANAGER", address(loanManagerFactory), false);

        vm.expectRevert("MH:SPL:INVALID_LM_FACTORY");
        _callSetPendingLenders();

        globals.__setValidFactory("LOAN_MANAGER", address(loanManagerFactory), true);

        _callSetPendingLenders();
    }

    function test_setPendingLenders_notActive() external {
        poolV2Manager.__setActive(false);

        vm.expectRevert("MH:SPL:PM_NOT_ACTIVE");
        _callSetPendingLenders();

        poolV2Manager.__setActive(true);

        _callSetPendingLenders();
    }

    function test_setPendingLenders_notOwnedPM() external {
        globals.__setOwnedPoolManager(address(poolDelegate), address(1));

        vm.expectRevert("MH:SPL:NOT_OWNED_PM");
        _callSetPendingLenders();

        globals.__setOwnedPoolManager(address(poolDelegate), address(poolV2Manager));

        _callSetPendingLenders();
    }

    function test_setPendingLenders_notPoolDelegate() external {
        globals.__setIsPoolDelegate(address(poolDelegate), false);

        vm.expectRevert("MH:SPL:INVALID_PD");
        _callSetPendingLenders();

        globals.__setIsPoolDelegate(address(poolDelegate), true);

        _callSetPendingLenders();
    }

    function test_setPendingLenders_invalidLoanFactory() external {
        globals.__setValidFactory("LOAN", address(loanFactory), false);

        vm.expectRevert("MH:SPL:INVALID_LOAN_FACTORY");
        _callSetPendingLenders();

        globals.__setValidFactory("LOAN", address(loanFactory), true);

        _callSetPendingLenders();
    }

    function test_setPendingLenders_invalidDebtLockerPool() external {
        debtLocker1.__setPool(address(1));

        vm.expectRevert("MH:SPL:INVALID_DL_POOL");
        _callSetPendingLenders();

        debtLocker1.__setPool(address(poolV1));
        debtLocker2.__setPool(address(1));

        vm.expectRevert("MH:SPL:INVALID_DL_POOL");
        _callSetPendingLenders();

        debtLocker2.__setPool(address(poolV1));

        _callSetPendingLenders();
    }

    function test_setPendingLenders_invalidLoan() external {
        loanFactory.__setIsLoan(address(loan1), false);

        vm.expectRevert("MH:SPL:INVALID_LOAN");
        _callSetPendingLenders();

        loanFactory.__setIsLoan(address(loan1), true);
        loanFactory.__setIsLoan(address(loan2), false);

        vm.expectRevert("MH:SPL:INVALID_LOAN");
        _callSetPendingLenders();

        loanFactory.__setIsLoan(address(loan2), true);

        _callSetPendingLenders();
    }

    function test_setPendingLenders() external {
        _callSetPendingLenders();
    }

    function test_setPendingLenders_rollback() external {
        address[] memory loans = new address[](2);
        loans[0] = address(loan1);
        loans[1] = address(loan2);

        vm.startPrank(owner);
        migrationHelper.setPendingLenders(address(poolV1), address(poolV2Manager), address(loanFactory), loans);
        migrationHelper.rollback_setPendingLenders(loans);
    }

}

contract AddLoansToLoanManagerTests is MigrationHelperTestBase {

    function _callAddLoansToLoanManager() internal {
        address[] memory loans = new address[](2);
        loans[0] = address(loan1);
        loans[1] = address(loan2);

        vm.prank(owner);
        migrationHelper.addLoansToLoanManager(address(loanManager), loans);
    }

    function test_addLoansToLoanManager_notAdmin() external {
        address[] memory loans = new address[](2);
        loans[0] = address(loan1);
        loans[1] = address(loan2);

        vm.expectRevert("MH:ONLY_ADMIN");
        migrationHelper.setPendingLenders(address(poolV1), address(poolV2Manager), address(loanFactory), loans);

        _callAddLoansToLoanManager();
    }

    function test_addLoansToLoanManager_protocolPaused() external {
        globals.__setProtocolPaused(true);

        vm.expectRevert("MH:ALTLM:PROTOCOL_PAUSED");
        _callAddLoansToLoanManager();

        globals.__setProtocolPaused(false);

        _callAddLoansToLoanManager();
    }

    function test_addLoansToLoanManager_invalidLoanManager() external {
        loanManagerFactory.__setIsInstance(address(loanManager), false);

        vm.expectRevert("MH:ALTLM:INVALID_LM");
        _callAddLoansToLoanManager();

        loanManagerFactory.__setIsInstance(address(loanManager), true);

        _callAddLoansToLoanManager();
    }

    function test_addLoansToLoanManager_claimableFunds() external {
        loan1.__setClaimableFunds(1);

        vm.expectRevert("MH:ALTLM:CLAIMABLE_FUNDS");
        _callAddLoansToLoanManager();

        loan1.__setClaimableFunds(0);

        _callAddLoansToLoanManager();
    }

    function test_addLoansToLoanManager() external {
        _callAddLoansToLoanManager();
    }

}

contract AdminTests is TestUtils {

    address migrationHelperImplementation;

    address globals      = address(new Address());
    address owner        = address(new Address());
    address pendingAdmin = address(new Address());

    MigrationHelper migrationHelper;

    function setUp() external {
        migrationHelperImplementation = address(new MigrationHelper());

        migrationHelper = MigrationHelper(address(new NonTransparentProxy(owner, migrationHelperImplementation)));
    }

    function test_setPendingAdmin_notAdmin() external {
        vm.expectRevert("MH:ONLY_ADMIN");
        migrationHelper.setPendingAdmin(address(1));
    }

    function test_setPendingAdmin() external {
        assertEq(migrationHelper.pendingAdmin(), address(0));

        vm.prank(owner);
        migrationHelper.setPendingAdmin(pendingAdmin);

        assertEq(migrationHelper.pendingAdmin(), pendingAdmin);
    }

    function test_acceptOwner_notPendingAdmin() external {
        vm.prank(owner);
        migrationHelper.setPendingAdmin(pendingAdmin);

        vm.expectRevert("MH:AO:NO_AUTH");
        migrationHelper.acceptOwner();
    }

    function test_acceptOwner() external {
        vm.prank(owner);
        migrationHelper.setPendingAdmin(pendingAdmin);

        assertEq(migrationHelper.pendingAdmin(), pendingAdmin);
        assertEq(migrationHelper.admin(),        owner);

        vm.prank(pendingAdmin);
        migrationHelper.acceptOwner();

        assertEq(migrationHelper.pendingAdmin(), address(0));
        assertEq(migrationHelper.admin(),        pendingAdmin);
    }

    function test_setGlobals_notAdmin() external {
        vm.expectRevert("MH:ONLY_ADMIN");
        migrationHelper.setGlobals(address(1));
    }

    function test_setGlobals() external {
        assertEq(migrationHelper.globalsV2(), address(0));

        vm.prank(owner);
        migrationHelper.setGlobals(globals);

        assertEq(migrationHelper.globalsV2(), globals);
    }

}

contract AirdropTokensTests is TestUtils {

    address migrationHelperImplementation;

    address globals      = address(new Address());
    address owner        = address(new Address());
    address poolDelegate = address(new Address());

    MigrationHelper migrationHelper;

    MockERC20         liquidityAsset;
    MockERC20         poolV2;
    MockPoolV1        poolV1;
    MockPoolV2Manager poolManager;

    function setUp() external {
        migrationHelperImplementation = address(new MigrationHelper());

        migrationHelper = MigrationHelper(address(new NonTransparentProxy(owner, migrationHelperImplementation)));

        liquidityAsset = new MockERC20("Liquidity Asset", "LA", 6);
        poolV2         = new MockERC20("POOL", "POOL", 6);
        poolV1         = new MockPoolV1();
        poolManager    = new MockPoolV2Manager();

        poolManager.__setPool(address(poolV2));
        poolManager.__setPoolDelegate(address(poolDelegate));
    }

    function test_airdropTokens_notAdmin() external {
        address lp1 = address(new Address());
        address lp2 = address(new Address());

        address[] memory lps = new address[](2);
        lps[0] = lp1;
        lps[1] = lp2;

        vm.expectRevert("MH:ONLY_ADMIN");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 1);
    }

    function test_airdropTokens_aboveAllowedDiff() external {
        address lp1 = address(new Address());
        address lp2 = address(new Address());

        address[] memory lps = new address[](2);
        lps[0] = lp1;
        lps[1] = lp2;

        poolV1.__setBalanceOf(lp1, 1000e18);
        poolV1.__setBalanceOf(lp2, 2000e18);

        poolV1.__setWithdrawableFundsOf(lp1, 100e6);
        poolV1.__setWithdrawableFundsOf(lp2, 200e6);

        poolV1.__setRecognizableLossesOf(lp1, 10e6);
        poolV1.__setRecognizableLossesOf(lp2, 20e6);

        poolV1.__setTotalSupply(3000e18);
        poolV1.__setInterestSum(300e6);
        poolV1.__setPoolLosses(30e6);
        poolV1.__setLiquidityAsset(address(liquidityAsset));

        poolV2.mint(address(migrationHelper), 3330e18);

        vm.startPrank(owner);

        poolV1.__setBalanceOf(lp1, (1000e6 + 1) * 1e12);  // For conversion to 6 decimals

        vm.expectRevert("MH:AT:VALUE_MISMATCH");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        poolV1.__setBalanceOf(lp1, 1000e18);
        poolV1.__setBalanceOf(lp2, (12000e6 + 1) * 1e12);  // For conversion to 6 decimals

        vm.expectRevert("MH:AT:VALUE_MISMATCH");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        poolV1.__setBalanceOf(lp2, 2000e18);
        poolV1.__setWithdrawableFundsOf(lp1, 100e6 + 1);

        vm.expectRevert("MH:AT:VALUE_MISMATCH");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        poolV1.__setWithdrawableFundsOf(lp1, 100e6);
        poolV1.__setWithdrawableFundsOf(lp2, 200e6 + 1);

        vm.expectRevert("MH:AT:VALUE_MISMATCH");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        poolV1.__setWithdrawableFundsOf(lp2, 200e6);
        poolV1.__setRecognizableLossesOf(lp1, 10e6 - 1);

        vm.expectRevert("MH:AT:VALUE_MISMATCH");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        poolV1.__setRecognizableLossesOf(lp1, 10e6);
        poolV1.__setRecognizableLossesOf(lp2, 20e6 - 1);

        vm.expectRevert("MH:AT:VALUE_MISMATCH");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        poolV1.__setRecognizableLossesOf(lp2, 20e6);
        poolV1.__setTotalSupply((3000e6 + 1) * 1e12);  // For conversion to 6 decimals

        vm.expectRevert("MH:AT:VALUE_MISMATCH");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        poolV1.__setTotalSupply(3000e18);
        poolV1.__setInterestSum(300e6 + 1);

        vm.expectRevert("MH:AT:VALUE_MISMATCH");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        poolV1.__setInterestSum(300e6);
        poolV1.__setPoolLosses(30e6 - 1);

        vm.expectRevert("MH:AT:VALUE_MISMATCH");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        poolV1.__setPoolLosses(30e6);

        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 1);
    }

    function test_airdropTokens_aboveAllowedDiff_negative() external {
        address lp1 = address(new Address());
        address lp2 = address(new Address());

        address[] memory lps = new address[](2);
        lps[0] = lp1;
        lps[1] = lp2;

        poolV1.__setBalanceOf(lp1, 1000e18);
        poolV1.__setBalanceOf(lp2, 2000e18);

        poolV1.__setWithdrawableFundsOf(lp1, 100e6);
        poolV1.__setWithdrawableFundsOf(lp2, 200e6);

        poolV1.__setRecognizableLossesOf(lp1, 10e6);
        poolV1.__setRecognizableLossesOf(lp2, 20e6);

        poolV1.__setTotalSupply(3000e18);
        poolV1.__setInterestSum(300e6);
        poolV1.__setPoolLosses(30e6);
        poolV1.__setLiquidityAsset(address(liquidityAsset));

        poolV2.mint(address(migrationHelper), 3330e18);

        vm.startPrank(owner);

        poolV1.__setBalanceOf(lp1, (1000e6 - 1) * 1e12);  // For conversion to 6 decimals

        vm.expectRevert("MH:AT:VALUE_MISMATCH");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        poolV1.__setBalanceOf(lp1, 1000e18);
        poolV1.__setBalanceOf(lp2, (12000e6 - 1) * 1e12);  // For conversion to 6 decimals

        vm.expectRevert("MH:AT:VALUE_MISMATCH");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        poolV1.__setBalanceOf(lp2, 2000e18);
        poolV1.__setWithdrawableFundsOf(lp1, 100e6 - 1);

        vm.expectRevert("MH:AT:VALUE_MISMATCH");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        poolV1.__setWithdrawableFundsOf(lp1, 100e6);
        poolV1.__setWithdrawableFundsOf(lp2, 200e6 - 1);

        vm.expectRevert("MH:AT:VALUE_MISMATCH");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        poolV1.__setWithdrawableFundsOf(lp2, 200e6);
        poolV1.__setRecognizableLossesOf(lp1, 10e6 + 1);

        vm.expectRevert("MH:AT:VALUE_MISMATCH");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        poolV1.__setRecognizableLossesOf(lp1, 10e6);
        poolV1.__setRecognizableLossesOf(lp2, 20e6 + 1);

        vm.expectRevert("MH:AT:VALUE_MISMATCH");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        poolV1.__setRecognizableLossesOf(lp2, 20e6);
        poolV1.__setTotalSupply((3000e6 - 1) * 1e12);  // For conversion to 6 decimals

        vm.expectRevert("MH:AT:VALUE_MISMATCH");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        poolV1.__setTotalSupply(3000e18);
        poolV1.__setInterestSum(300e6 - 1);

        vm.expectRevert("MH:AT:VALUE_MISMATCH");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        poolV1.__setInterestSum(300e6);
        poolV1.__setPoolLosses(30e6 + 1);

        vm.expectRevert("MH:AT:VALUE_MISMATCH");
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        poolV1.__setPoolLosses(30e6);

        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 1);
    }

    function test_airdropTokens_exact() external {
        address lp1 = address(new Address());
        address lp2 = address(new Address());

        address[] memory lps = new address[](2);
        lps[0] = lp1;
        lps[1] = lp2;

        poolV1.__setBalanceOf(lp1, 1000e18);
        poolV1.__setBalanceOf(lp2, 2000e18);

        poolV1.__setWithdrawableFundsOf(lp1, 100e6);
        poolV1.__setWithdrawableFundsOf(lp2, 200e6);

        poolV1.__setRecognizableLossesOf(lp1, 10e6);
        poolV1.__setRecognizableLossesOf(lp2, 20e6);

        poolV1.__setTotalSupply(3000e18);
        poolV1.__setInterestSum(300e6);  // One too low
        poolV1.__setPoolLosses(30e6);
        poolV1.__setLiquidityAsset(address(liquidityAsset));

        poolV2.mint(address(migrationHelper), 3330e18);

        vm.startPrank(owner);
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);
    }

    function test_airdropTokens_remaining() external {
        address lp1 = address(new Address());
        address lp2 = address(new Address());

        address[] memory lps = new address[](2);
        lps[0] = lp1;
        lps[1] = lp2;

        poolV1.__setBalanceOf(lp1, 1000e18);
        poolV1.__setBalanceOf(lp2, 2000e18);

        poolV1.__setWithdrawableFundsOf(lp1, 100e6);
        poolV1.__setWithdrawableFundsOf(lp2, 200e6);

        poolV1.__setRecognizableLossesOf(lp1, 10e6);
        poolV1.__setRecognizableLossesOf(lp2, 20e6);

        poolV1.__setTotalSupply(3000e18);
        poolV1.__setInterestSum(300e6);  // One too low
        poolV1.__setPoolLosses(30e6);
        poolV1.__setLiquidityAsset(address(liquidityAsset));

        poolV2.mint(address(migrationHelper), 3271e6);

        vm.startPrank(owner);
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, 0);

        assertEq(poolV2.balanceOf(poolDelegate), 1e6);
    }

}

// TODO: test takeOwnershipOfLoans and rollback
// TODO: test upgradeLoanManager and rollback
