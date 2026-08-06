# Containerised Environments

This repository provides a framework for deploying conda environments on High-Performance Computing (HPC) systems using Apptainer (used to be known as Singularity) containers and SquashFS overlays. This approach significantly reduces inode consumption and improves performance by encapsulating thousands of environment files into a single compressed image, while maintaining the flexibility of a standard Conda installation.

For an AI-generated overview of this repository --> [![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/ACCESS-NRI/containerised-environments-infra)