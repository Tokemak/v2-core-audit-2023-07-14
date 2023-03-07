# Foundry Template

[![Github Actions][gha-badge]][gha] [![Foundry][foundry-badge]][foundry] [![semantic-release: convential commits][commits-badge]][commits] [![protected by: gitleaks][gitleaks-badge]][gitleaks] [![License: MIT][license-badge]][license]

[gha]: https://github.com/codenutt/foundry-template/actions
[gha-badge]: https://github.com/codenutt/foundry-template/actions/workflows/ci.yml/badge.svg
[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[commits]: https://github.com/semantic-release/semantic-release
[commits-badge]: https://img.shields.io/badge/semantic--release-conventialcommits-e10079?logo=semantic-release
[license]: https://opensource.org/licenses/MIT
[license-badge]: https://img.shields.io/badge/License-MIT-blue.svg
[gitleaks-badge]: https://img.shields.io/badge/protected%20by-gitleaks-blue
[gitleaks]: https://gitleaks.io/

A fairly strict and opinionated Foundry-based template for developing Solidity smart contracts.

## What are you getting

-   Forge + Forge Std library
-   Solhint
-   Prettier
-   ESLint
-   Conventional Commits
-   Semantic Versioning
-   GitHub CI
-   Gitleaks
-   Slither

## Getting Started

Install the same version of foundry that the CI will use. Ensures formatting stays consistent

```
 foundryup --version nightly-a44159a5c23d2699d3a390e6d4889b89a0e5a5e0
```

You can use the `Use this template` button in GitHub to create a new repository. We will not go over setting up Foundry here.
You should update the following based on your repo/project:

-   `package.json`
    -   `name`
    -   `repository.url`
-   `LICENSE`
    -   `Copyright`

To get going from there:

```
npm install
```

In GitHub, you will want to configure an Action secret of `GH_TOKEN` with permissions to write to the repo.
This is for creating tags and releases after a push to main. More information can be found here:
https://github.com/semantic-release/semantic-release/blob/master/docs/usage/ci-configuration.md#ci-configuration

### Gitleaks

You will need to install gitleaks locally. For details: https://github.com/zricethezav/gitleaks#installing.
If you are an Organization, you will need a Gitleaks license in order to run the Action. That license should be setup
as a secret under the variable name `GITLEAKS_LICENSE`

## Features

### Conventional Commits

[Conventional Commits](https://www.conventionalcommits.org/) are enforced on this template. Locally, this is enforced via Husky. GitHub CI is setup to enforce it there as well.
If a commit does not follow the guidelines, the build/PR will be rejected.

### Linting and Formatting

Formatting for Solidity files is provided via `forge`. Other files are formatted via `prettier`. Linting is provided by `solhint` and `eslint`.

### Versioning

Semantic versioning drives tag and release information when commits are pushed to main. Your commit will automatically tagged with the version number,
and a release will be created in GitHub with the change log.

### Security Scanning

#### Slither

Slither will run automatically in CI. To run the `scan:slither` command locally you'll need to ensure you have Slither installed: https://github.com/crytic/slither#how-to-install
