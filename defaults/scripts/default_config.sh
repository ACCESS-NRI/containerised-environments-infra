# This script is sourced at the beginning of the `install_config.sh` script to replace the default
# values of some environment variables used for the deployment.

# Specific environments should override this script by defining the 
# `environments/<env_name>/overrides/scripts/default_config.sh` file.


# INTERNAL_ENV_DIR 
# Absolute path (must start with '/') where the environment will be located within the container
export INTERNAL_ENV_DIR=

# MAMBA_EXE
# Mircomamba executable used to manage conda environments
export MAMBA_EXE=

# ENV_PROMPT_MODIFIER
# The modifier that can be used to change the PS1 prompt after the environment is activated
export ENV_PROMPT_MODIFIER=

# PYTHONNOUSERSITE
# Set to false to include user local Python packages in the Python environment
export PYTHONNOUSERSITE=

# PYTHONDONTWRITEBYTECODE
# Set to 0 to allow Python to write bytecode cache (.pyc files). Set to 1 to prevent writing of .pyc files.
export PYTHONDONTWRITEBYTECODE=

# HOST_EXECUTABLES
# Comma-separated list of executables not to be symlinked to the launcher script.
# These executables will always run on the host and not inside the container,
# even if they are present in the environment's bin directory.
export HOST_EXECUTABLES=

# ADDITIONAL_CONTAINER_OVERLAYS
# Comma-separated list of additional paths to squashfs environments to overlay
# to the container at runtime, and therefore make available within
# the container.
export ADDITIONAL_CONTAINER_OVERLAYS=