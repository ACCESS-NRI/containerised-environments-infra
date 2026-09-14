# Containerised Environments

This repository provides a framework for deploying conda-like environments on High-Performance Computing (HPC) systems using Apptainer (used to be known as Singularity) containers and SquashFS overlays. This approach significantly reduces inode consumption and improves performance by encapsulating thousands of environment files into a single compressed image, while maintaining the flexibility of a standard conda environment installation.

## Overview

For an AI-generated detailed overview of this repository --> [![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/ACCESS-NRI/containerised-environments-infra)

## How to add a new environment

1. Open an issue related to the environment, listing the specifics of the environment (e.g. required packages, target HPC systems) and what it is needed for.
2. In a new branch (branched from `main`) create a new folder under [environments](environments/), named after the environment. The environment name must be hyphenated (no underscores).
In this folder there should be:
  - An environment specification `environment.yml` file.
  - An optional dev specification `environment_dev.yml` file.
  - Other optional override files (see the wiki for more info on overrides).

## Environments versioning

The version of an environment can have any structure (e.g., `1.2.0`, `myver`, `2026.01.0_main`). However, if the version follows the versioning of an internal "core" package (for example, the [payu](environments/payu/) environment, which is versioned following the version of the internal `payu` package), an additional `..._X` portion should be appended to the "core" version, with `X` starting from `0` and increasing (e.g., `1.2.0_0`, `myversion_2`). This allows multiple versions of the environment with the same "core" package version to be released.

When using this `..._X` versioning scheme, an override for the `.modulerc` file should also be added to the environment, so that the latest `..._X` version is automatically detected and loaded.
This can be copied from the [`payu` environment `.modulerc` override](https://github.com/ACCESS-NRI/containerised-environments-infra/blob/main/environments/payu/overrides/modules/.modulerc).

## How to release a new environment version

To release a new environment version, trigger the [`release_module.yml`](https://github.com/ACCESS-NRI/containerised-environments-infra/actions/workflows/release_module.yml) GitHub Actions workflow:

1. Go to the **Actions** tab in the repository
2. Select the **release_module** workflow
3. Click **Run workflow** and provide:
   - The environment name (as it appears in the [`environments/`](environments/) folder)
   - The version to release (following the [versioning scheme](#environments-versioning) described above)

## Release/deployment approval and progression

Once a release/deployment workflow is triggered:

1. **Approval step** — A repository admin will review and approve the deployment
2. **Build and deployment** — The workflow will build the containerised environment and deploy it to the HPC systems
3. **Monitor progress** — You can track the workflow run in the [**Actions**](https://github.com/ACCESS-NRI/containerised-environments-infra/actions) tab to see real-time build status
4. **GitHub release** — For stable environments releases, a new tag and GitHub release is automatically created with instructions on how to load and use the environment on each HPC system