# Containerised Environments Modules

This repository provides a framework for deploying modules that load conda-like environments on High-Performance Computing (HPC) systems using Apptainer (used to be known as Singularity) containers and SquashFS overlays. This approach significantly reduces inode consumption and improves performance by encapsulating thousands of environment files into a single compressed image, while keeping usability as simple as running a TCL modules construct:
```
module use ...
module load ...
```

## Overview
For an AI-generated detailed overview of this repository --> [![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/ACCESS-NRI/containerised-environments-infra)
  - [Module deployment scenarios: STABLE vs. DEVELOPMENT and STAGING vs. PRODUCTION](#module-deployments-stable-vs-development-and-staging-vs-production)
    - [Module Types](#module-types)
    - [Deployment Stages](#deployment-stages)
    - [Module Deployment Scenarios Matrix](#module-deployment-scenarios-matrix)
  - [How to add a new environment](#how-to-add-a-new-environment)
  - [Environments versioning](#environments-versioning)
  - [How to release a new STABLE environment](#how-to-release-a-new-stable-environment)
  - [How to release a new DEVELOPMENT environment](#how-to-release-a-new-development-environment)
  - [Release/deployment approval and progression](#releasedeployment-approval-and-progression)

## Module deployments: STABLE vs. DEVELOPMENT and STAGING vs. PRODUCTION

There are 4 possible module deployment scenarios, determined by the _module type_ and _deployment stage_: 

### Module Types
**STABLE**<br>
Used for non-development modules. The environment is typically defined by fixed versions in `environment.yml` and installed from stable channels like Anaconda.org.

**DEVELOPMENT**<br>
Used for testing development packages, often installed via pip + git from specific repository refs as defined in `environment_dev.yml`.

### Deployment Stages
**STAGING**<br>
A testing area used for automated infrastructure validation and testing during CI (e.g., Pull Requests).

**PRODUCTION**<br>
The live modules accessed by end-users.

### Module Deployment Scenarios Matrix
| | STABLE | DEVELOPMENT |
|---|---|---|
| **PRODUCTION** | Stable modules for day-to-day user workflows | Dev modules for user functional testing |
| **STAGING** | Stable modules deployed for CI testing | Dev modules deployed for CI testing |


## How to add a new environment

1. Open an issue listing the following information about the new environment:
   - environment name
   - required packages
   - target HPC systems
   - what it is needed for
2. In a new branch (branched from `main`) create a subdirectory within [environments](environments/), named after the new environment. The environment name must be hyphenated (no spaces or underscores).
In this folder add:
    - An environment specification `environment.yml` file.
    - An optional dev specification `environment_dev.yml` file.
    - Other optional [override files](https://deepwiki.com/ACCESS-NRI/containerised-environments-infra/1.1-getting-started-and-repository-layout#overrides-pattern).

## Environments versioning

The version of an environment can have any structure (e.g., `1.2.0`, `myver`, `2026.01.0_main`). However, if the version follows the versioning of an internal "core" package (for example, the [payu](environments/payu/) environment, which is versioned following the version of the internal `payu` package), an additional `..._X` portion should be appended to the "core" version, with `X` starting from `0` and increasing (e.g., `1.2.0_0`, `myversion_2`). This allows multiple versions of the environment with the same "core" package version to be released.

When using this `..._X` versioning scheme, an override for the `.modulerc` file should also be added to the environment, so that the latest `..._X` version is automatically detected and loaded.
This can be copied from the [`payu` environment `.modulerc` override](https://github.com/ACCESS-NRI/containerised-environments-infra/blob/main/environments/payu/overrides/modules/.modulerc).

## How to release a new STABLE environment

To release a new STABLE environment version for PRODUCTION, trigger the [`release_module.yml`](https://github.com/ACCESS-NRI/containerised-environments-infra/actions/workflows/release_module.yml) GitHub Actions workflow:

Click **Run workflow** and provide:
   - The environment name (as it appears in the [`environments/`](environments/) folder)
   - The version to release (following the [versioning scheme](#environments-versioning) described above)

## How to release a new DEVELOPMENT environment

To release a new DEVELOPMENT environment version for PRODUCTION, trigger the [`release_dev_module.yml`](https://github.com/ACCESS-NRI/containerised-environments-infra/actions/workflows/release_dev_module.yml) GitHub Actions workflow:

Click **Run workflow** and provide:
   - The environment name (as it appears in the [`environments/`](environments/) folder)

## Release/deployment approval and progression

Once a release/deployment workflow is triggered:

1. **Approval step** — A repository admin will review and approve the deployment
2. **Build and deployment** — The workflow will build the containerised environment and deploy it to the HPC systems
3. **Monitor progress** — You can track the workflow run in the [**Actions**](https://github.com/ACCESS-NRI/containerised-environments-infra/actions) tab to see real-time build status
4. **GitHub release** — For stable environments releases, a new tag and GitHub release is automatically created with instructions on how to load and use the environment on each HPC system