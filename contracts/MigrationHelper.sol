// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { IDebtLockerLike, IMapleLoanLike } from "./interfaces/Interfaces.sol";

contract MigrationHelper {

    function setPendingLender(address[] calldata loans, address investmentManager) external {
        for (uint256 i = 0; i < loans.length; i++) {
            // Set pending lender through debt locker
            IDebtLockerLike(IMapleLoanLike(loans[i]).lender()).setPendingLender(investmentManager);
        }
    }

}
