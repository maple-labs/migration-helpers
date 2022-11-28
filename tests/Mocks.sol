// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

contract MockDebtLocker {

    address public loan;
    address public pool;

    function setPendingLender(address pendingLender_) external {
        MockLoan(loan).setPendingLender(pendingLender_);
    }

    function __setLoan(address loan_) external {
        loan = loan_;
    }

    function __setPool(address pool_) external {
        pool = pool_;
    }

}

contract MockGlobals {

    address public pool;
    address public pendingLender;

    bool public protocolPaused;

    mapping(address => address) public ownedPoolManager;

    mapping(address => bool) public isPoolDelegate;

    mapping(bytes32 => mapping(address => bool)) public isFactory;

    function setPendingLender(address newLender_) external {
        pendingLender = newLender_;
    }

    function poolDelegates(address poolDelegate_) external view returns (address ownedPoolManager_, bool isPoolDelegate_) {
        ownedPoolManager_ = ownedPoolManager[poolDelegate_];
        isPoolDelegate_   = isPoolDelegate[poolDelegate_];
    }

    function __setIsPoolDelegate(address poolDelegate_, bool isValid_) external {
        isPoolDelegate[poolDelegate_] = isValid_;
    }

    function __setOwnedPoolManager(address poolDelegate_, address poolManager_) external {
        ownedPoolManager[poolDelegate_] = poolManager_;
    }

    function __setProtocolPaused(bool paused_) external {
        protocolPaused = paused_;
    }

    function __setValidFactory(bytes32 key_, address factory_, bool valid_) external {
        isFactory[key_][factory_] = valid_;
    }

}

contract MockLoan {

    address public implementation;
    address public lender;
    address public pendingLender;

    uint256 public claimableFunds;
    uint256 public nextPaymentDueDate;
    uint256 public principal;

    function setPendingLender(address newLender_) external {
        pendingLender = newLender_;
    }

    function __setClaimableFunds(uint256 claimableFunds_) external {
        claimableFunds = claimableFunds_;
    }

    function __setImplementation(address implementation_) external {
        implementation = implementation_;
    }

    function __setLender(address lender_) external {
        lender = lender_;
    }

    function __setNextPaymentDueDate(uint256 nextPaymentDueDate_) external {
        nextPaymentDueDate = nextPaymentDueDate_;
    }

    function __setPrincipal(uint256 principal_) external {
        principal = principal_;
    }

}

contract MockLoanFactory {

    uint256 public defaultVersion;

    mapping(address => bool) public isLoan;

    mapping(uint256 => address) public implementationOf;

    function __setDefaultVersion(uint256 defaultVersion_) external {
        defaultVersion = defaultVersion_;
    }

    function __setImplementation(uint256 version_, address implementation_) external {
        implementationOf[version_] = implementation_;
    }

    function __setIsLoan(address loan_, bool valid_) external {
        isLoan[loan_] = valid_;
    }

}

contract MockLoanManager {

    address public factory;

    function __setFactory(address factory_) external {
        factory = factory_;
    }

    function add(address loan_) external {
        // Do nothing
    }

}

contract MockPoolV1 {

    address public liquidityAsset;

    uint256 public interestSum;
    uint256 public poolLosses;
    uint256 public principalOut;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public recognizableLossesOf;
    mapping(address => uint256) public withdrawableFundsOf;

    function __setBalanceOf(address account_, uint256 balance_) external {
        balanceOf[account_] = balance_;
    }

    function __setInterestSum(uint256 interestSum_) external {
        interestSum = interestSum_;
    }

    function __setLiquidityAsset(address liquidityAsset_) external {
        liquidityAsset = liquidityAsset_;
    }

    function __setPoolLosses(uint256 poolLosses_) external {
        poolLosses = poolLosses_;
    }

    function __setPrincipalOut(uint256 principalOut_) external {
        principalOut = principalOut_;
    }

    function __setTotalSupply(uint256 totalSupply_) external {
        totalSupply = totalSupply_;
    }

    function __setRecognizableLossesOf(address account_, uint256 amount_) external {
        recognizableLossesOf[account_] = amount_;
    }

    function __setWithdrawableFundsOf(address account_, uint256 amount_) external {
        withdrawableFundsOf[account_] = amount_;
    }

}

contract MockPoolV2Manager {

    address public pool;
    address public factory;
    address public poolDelegate;

    bool public active;

    address[] public loanManagerList;

    function __setActive(bool active_) external {
        active = active_;
    }

    function __setFactory(address factory_) external {
        factory = factory_;
    }

    function __setPool(address pool_) external {
        pool = pool_;
    }

    function __setPoolDelegate(address poolDelegate_) external {
        poolDelegate = poolDelegate_;
    }

    function __setLoanManager(address loanManager_) external {
        loanManagerList.push(loanManager_);
    }

    function __setLoanManagerAtIndex(uint256 index, address loanManager_) external {
        loanManagerList[index] = loanManager_;
    }
}

contract MockProxyFactory {

    mapping(address => bool) public isInstance;

    function __setIsInstance(address instance_, bool valid_) external {
        isInstance[instance_] = valid_;
    }

}


