# This file is sourced in the build_and_deploy_env.sh script to cleanup oldest DEVELOPMENT
# modules for PRODUCTION if the number of dev env versions is greater than MAX_DEV_MODULE_VERSIONS

# Only for DEVELOPMENT envs in PRODUCTION
if [[ "$MODULE_TYPE" == DEVELOPMENT ]] && [[ "$DEPLOYMENT_STAGE" == PRODUCTION ]]; then
    module_versions=$(
        find "$APP_DIR" \
        -mindepth 1 -maxdepth 1 \
        -type d \
        -printf '%T+ %p\n' \
        | sort
    )
    num_versions=$(echo "$module_versions" | wc -l)
    if [[ $num_versions -gt $MAX_DEV_MODULE_VERSIONS ]]; then
        oldest_version_dir=$(echo "$module_versions" | head -n 1 | cut -d' ' -f2-)
        oldest_version_manifest="$oldest_version_dir/$FILES_MANIFEST_NAME"
        oldest_version=$(basename "$oldest_version_dir")
        msg="Number of '$MODULE_NAME' DEVELOPMENT versions in PRODUCTION greater than '$MAX_DEV_MODULE_VERSIONS'. "
        msg+="Cleaning up oldest '$MODULE_NAME' DEVELOPMENT version: $oldest_version"
        echo "$msg"
        delete_files_in_manifest "$oldest_version_manifest"
    fi
fi