// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { Address, console, TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { NonTransparentProxy } from "../modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

import { MigrationHelper } from "../contracts/MigrationHelper.sol";

import {
    MockDebtLocker,
    MockGlobals,
    MockLoan,
    MockLoanManager,
    MockLoanFactory,
    MockPoolV2Manager,
    MockProxyFactory
} from "./Mocks.sol";

contract TransferLoansTests is TestUtils {

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
    }

    function _callTransferLoans() internal {
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

        _callTransferLoans();
    }

    function test_setPendingLenders_protocolPaused() external {
        globals.__setProtocolPaused(true);

        vm.expectRevert("MH:SPL:PROTOCOL_PAUSED");
        _callTransferLoans();

        globals.__setProtocolPaused(false);

        _callTransferLoans();
    }

    function test_setPendingLenders_invalidPoolManager() external {
        poolManagerFactory.__setIsInstance(address(poolV2Manager), false);

        vm.expectRevert("MH:SPL:INVALID_PM");
        _callTransferLoans();

        poolManagerFactory.__setIsInstance(address(poolV2Manager), true);

        _callTransferLoans();
    }

    function test_setPendingLenders_invalidPMFactory() external {
        globals.__setValidFactory("POOL_MANAGER", address(poolManagerFactory), false);

        vm.expectRevert("MH:SPL:INVALID_PM_FACTORY");
        _callTransferLoans();

        globals.__setValidFactory("POOL_MANAGER", address(poolManagerFactory), true);

        _callTransferLoans();
    }

    function test_setPendingLenders_invalidLoanManager() external {
        loanManagerFactory.__setIsInstance(address(loanManager), false);

        vm.expectRevert("MH:SPL:INVALID_LM");
        _callTransferLoans();

        loanManagerFactory.__setIsInstance(address(loanManager), true);

        _callTransferLoans();
    }

    function test_setPendingLenders_invalidLMFactory() external {
        globals.__setValidFactory("LOAN_MANAGER", address(loanManagerFactory), false);

        vm.expectRevert("MH:SPL:INVALID_LM_FACTORY");
        _callTransferLoans();

        globals.__setValidFactory("LOAN_MANAGER", address(loanManagerFactory), true);

        _callTransferLoans();
    }

    function test_setPendingLenders_notActive() external {
        poolV2Manager.__setActive(false);

        vm.expectRevert("MH:SPL:PM_NOT_ACTIVE");
        _callTransferLoans();

        poolV2Manager.__setActive(true);

        _callTransferLoans();
    }

    function test_setPendingLenders_notOwnedPM() external {
        globals.__setOwnedPoolManager(address(poolDelegate), address(1));

        vm.expectRevert("MH:SPL:NOT_OWNED_PM");
        _callTransferLoans();

        globals.__setOwnedPoolManager(address(poolDelegate), address(poolV2Manager));

        _callTransferLoans();
    }

    function test_setPendingLenders_notPoolDelegate() external {
        globals.__setIsPoolDelegate(address(poolDelegate), false);

        vm.expectRevert("MH:SPL:INVALID_PD");
        _callTransferLoans();

        globals.__setIsPoolDelegate(address(poolDelegate), true);

        _callTransferLoans();
    }

    function test_setPendingLenders_invalidLoanFactory() external {
        globals.__setValidFactory("LOAN", address(loanFactory), false);

        vm.expectRevert("MH:SPL:INVALID_LOAN_FACTORY");
        _callTransferLoans();

        globals.__setValidFactory("LOAN", address(loanFactory), true);

        _callTransferLoans();
    }

    function test_setPendingLenders_invalidDebtLockerPool() external {
        debtLocker1.__setPool(address(1));

        vm.expectRevert("MH:SPL:INVALID_DL_POOL");
        _callTransferLoans();

        debtLocker1.__setPool(address(poolV1));
        debtLocker2.__setPool(address(1));

        vm.expectRevert("MH:SPL:INVALID_DL_POOL");
        _callTransferLoans();

        debtLocker2.__setPool(address(poolV1));

        _callTransferLoans();
    }

    function test_setPendingLenders_invalidLoan() external {
        loanFactory.__setIsLoan(address(loan1), false);

        vm.expectRevert("MH:SPL:INVALID_LOAN");
        _callTransferLoans();

        loanFactory.__setIsLoan(address(loan1), true);
        loanFactory.__setIsLoan(address(loan2), false);

        vm.expectRevert("MH:SPL:INVALID_LOAN");
        _callTransferLoans();

        loanFactory.__setIsLoan(address(loan2), true);

        _callTransferLoans();
    }

    function test_setPendingLenders() external {
        address[] memory loans = new address[](2);
        loans[0] = address(loan1);
        loans[1] = address(loan2);

        _callTransferLoans();
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
