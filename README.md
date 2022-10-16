# Pool V2 Migration Helpers

![Foundry CI](https://github.com/maple-labs/migration-helpers/actions/workflows/forge.yaml/badge.svg) [![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

## Overview

The `MigrationHelper` contract is a simple helper contract to atomically perform the transfer of many loans. This is designed to make the liquidity migration procedure both easier and more robust.

The `AccountingChecker` contract (in `contracts/checkers`) is a helper contract to check the value represented in the `LoanManager` contract against a naive calculation to ensure correctness.

## Setup

This project was built using [Foundry](https://book.getfoundry.sh/). Refer to installation instructions [here](https://github.com/foundry-rs/foundry#installation).

```sh
git clone git@github.com:maple-labs/migration-helpers.git
cd migration-helpers
forge install
```

## About Maple
[Maple Finance](https://maple.finance/) is a decentralized corporate credit market. Maple provides capital to institutional borrowers through globally accessible fixed-income yield opportunities.

For all technical documentation related to the Maple V2 protocol, please refer to the GitHub [wiki](https://github.com/maple-labs/maple-core-v2/wiki).

---

<p align="center">
  <img src="https://user-images.githubusercontent.com/44272939/116272804-33e78d00-a74f-11eb-97ab-77b7e13dc663.png" height="100" />
</p>
