// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

contract DeactivationOracle {

    // Purely returning 1 as a proof of concept, in actual migration we should use a more sophisticated oracle that handles atomically switching prices
    int256 constant DEACTIVATION_USD_PRICE = 1;

    /**
        @dev Returns the constant USD price.
    */
    function getLatestPrice() public pure returns (int256) {
        return DEACTIVATION_USD_PRICE;
    }
}
