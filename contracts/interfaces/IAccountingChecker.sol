// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

interface IAccountingChecker {

    function HUNDRED_PERCENT() external returns (uint256 hundredPercent_);

    function PRECISION() external returns (uint256 precision_);

    function SCALED_ONE() external returns (uint256 scaledOne_);

    function globals() external returns (address globals_);

    function checkPoolAccounting(
        address poolManager_,
        address[] calldata loans_,
        uint256 loansAddedTimestamp_,
        uint256 lastUpdatedTimestamp_
    )
        external view
        returns (
            uint256 expectedTotalAssets_,
            uint256 actualTotalAssets_,
            uint256 expectedDomainEnd_,
            uint256 actualDomainEnd_
        );

}
