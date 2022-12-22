// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

contract DeactivationOracle {

    int256 constant DEACTIVATION_USD_PRICE = 1;

    /**
        @dev Returns the constant USD price.
    */
    function getLatestPrice() public pure returns (int256) {
        return DEACTIVATION_USD_PRICE;
    }
}
