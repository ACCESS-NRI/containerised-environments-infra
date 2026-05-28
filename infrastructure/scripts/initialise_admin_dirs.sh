#!/usr/bin/env bash

# Script to create the admin directory and subdirectories on HPC and set the right permissions

set -euo pipefail
if [[ "${CONTAINERISED_ENVS_DEBUG:-0}" == "1" ]]; then
    set -x
fi

# Make functions available
source "$FUNCTIONS_PATH"

directories=(
    "$STABLE_PRODUCTION_BASE_DIR"
    "$ADMIN_DIR"
    "$LOGS_DIR"
)

# Create the directories and set the permissions only if they don't already exist
# to avoid changing permissions on existing directories
for dir in "${directories[@]}"; do
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        set_perms "$dir"
    fi
done