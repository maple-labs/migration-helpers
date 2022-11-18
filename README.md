# Pool V2 Migration Helpers

[![Foundry][foundry-badge]][foundry]
![Foundry CI](https://github.com/maple-labs/migration-helpers/actions/workflows/forge.yaml/badge.svg)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

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
  <img src="https://user-images.githubusercontent.com/44272939/196706799-fe96d294-f700-41e7-a65f-2d754d0a6eac.gif" height="100" />
</p>
