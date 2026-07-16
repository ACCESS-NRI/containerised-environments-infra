#!/usr/bin/env bash

# This script is used to delete the staging files associated to a STAGING module deployment.

# Usage: delete_staging_files.sh [<pr_number> | --all]

# There are three deletion cases:
# 1. PRODUCTION env deployed through a workflow dispatch.
#    In this case, there is only one staging module deployed and it can be identified through
#    the $MODULE_VERSION variable (this script doesn't need any additional parameters).
# 2. STAGING envs deployment within a Pull Request.
#    In this case, there can be multiple modules deployed within the same PR
#    (this script needs the pr_number positional parameter to identify all the modules associated with that PR).
# 3. All STAGING envs deployment.
#    In this case, all files in the staging directories (STABLE and DEVELOPMENT) will be deleted.
#    (this script needs the --all flag).

set -euo pipefail

if [[ "${CONTAINERISED_ENVS_DEBUG:-0}" == "1" ]]; then
    set -x
fi

# Sanity check on the input parameters
if [[ "$#" -gt 1 ]]; then
    echo "Error: too many parameters."
    exit 1
elif [[ ${1:-} != '--all' && ! ${1:-0} =~ ^[0-9]+$ ]]; then
    echo "Error: invalid parameter. Please provide either a PR number or the '--all' flag."
    exit 1
fi

# Set configuration env variables
source "$INFRA_SCRIPTS_DIR/install_config.sh"

# Delete module files
if [[ -z "${1:-}" ]]; then
    # No arguments are provided: only delete the files associated with the current version
    echo "Deleting STAGING files associated to version '$MODULE_VERSION':"
    delete_files_in_manifest "$FILES_MANIFEST_PATH"
elif [[ "${1:-}" == '--all' ]]; then
    # If --all flag is provided, delete all files in the staging directories
    # We perform an extra check to avoid runing the rm command with empty variables
    if [[ -z "$STABLE_STAGING_BASE_DIR" ]]; then
        echo "Error: STABLE_STAGING_BASE_DIR is empty"
        exit 1
    elif [[ -z "$DEVELOPMENT_STAGING_BASE_DIR" ]]; then
        echo "Error: DEVELOPMENT_STAGING_BASE_DIR is empty"
        exit 1
    else
        rm -vrf "$STABLE_STAGING_BASE_DIR"/* "$DEVELOPMENT_STAGING_BASE_DIR"/*
    fi
else
    pr_number="$1"
    # Pr number is provided: delete all files associated with that pr_number
    # Define regex to find all manifests of env versions associated with the pr_number
    regex=".*/.*-pr${pr_number}[^0-9]*/${FILES_MANIFEST_NAME}$"
    # We need to find both DEVELOPMENT and STABLE modules.
    # The DEVELOPMENT module directory is APP_DIR (because we run this within a workflow without
    # is_stable and its default value is false)
    # The STABLE module directory is derived from APP_DIR by removing the DEVELOPMENT_STAGING_BASE_DIR
    # prefix and adding the STABLE_STAGING_BASE_DIR prefix instead.
    development_env_dir="$APP_DIR"
    stable_env_dir="$STABLE_STAGING_BASE_DIR/${APP_DIR#$DEVELOPMENT_STAGING_BASE_DIR/}"
    # Only add directories if they exist, otherwise the find command below would fail
    dirs=()
    if [[ -d "$development_env_dir" ]]; then
      dirs+=("$development_env_dir")
    fi
    if [[ -d "$stable_env_dir" ]]; then
      dirs+=("$stable_env_dir")
    fi
    # Find all manifest files of env versions associated with the pr_number and delete all the related files
    while IFS= read -r manifest_file; do
        delete_files_in_manifest "$manifest_file"
    done < <(
      find "${dirs[@]}" \
      -type f \
      -regextype posix-extended \
      -regex "$regex"
    )
fi

