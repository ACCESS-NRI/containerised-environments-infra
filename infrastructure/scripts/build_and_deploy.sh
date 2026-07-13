#!/usr/bin/env bash

#PBS -q copyq
#PBS -l ncpus=1
#PBS -l walltime=2:00:00
#PBS -l mem=20GB
#PBS -l jobfs=50GB
#PBS -W umask=0037

set -euo pipefail
if [[ "${CONTAINERISED_ENVS_DEBUG:-0}" == "1" ]]; then
    set -x
fi

# Redirect STDOUT and STDERR of this shell to the PBS job log file, to 
# be able to capture all STDOUT and STDERR of the PBS job without having to wait
# for the job to end
exec &> "$JOB_LOG_FILE"

# Set configuration env variables
source "$INFRA_SCRIPTS_DIR/install_config.sh"

### Initialise directories
# Make sure the target module directory does not already exist, to avoid accidentally overwriting an existing environment.
if [[ -d "$APP_VERSION_DIR" ]]; then
    echo "Error! Module version '$MODULE_NAME/$MODULE_VERSION' already exists." >&2
    exit 1
fi
# Create a trap function that would delete the module version related files
# in case the script fails
cleanup_env() {
    # _exit_status vaiable is initialised within the register_exit_trap_cmd function
    if [ $_exit_status -ne 0 ]; then
        echo "Error! Build failed. Cleaning up module version '$MODULE_NAME/$MODULE_VERSION' related files..." >&2
        delete_files_in_manifest "$FILES_MANIFEST_PATH"
    fi
}
register_exit_trap_cmd cleanup_env $TRAP_PRIORITY_LAST

echo 'Initialising directories...'
if [[ ! -d "$BASE_DIR" ]]; then
    mkdir -p "$BASE_DIR"
    set_perms "$BASE_DIR"
fi
mkdir -pv "$APP_VERSION_DIR"
if [[ ! -d "$MODULE_DIR" ]]; then
    mkdir -p "$MODULE_DIR"
    set_perms "$MODULE_DIR"
fi
mkdir -pv "$ENV_BIN_DIR"
mkdir -pv "$(dirname "$TEMP_ENV_DIR")"


### CREATE HPC TARGET DEPLOYMENT INFO JSON
# Set a trap function to update the HPC target deployment info JSON when the script exits
update_hpc_target_deployment_info() {
    # _exit_status variable is initialised within the register_exit_trap_cmd function
    export SUCCESS=$( [ $_exit_status -eq 0 ] && echo true || echo false )
    # Update the HPC target deployment info JSON
    source "$INFRA_SCRIPTS_DIR/create_hpc_target_deployment_info_json.sh" \
        "$DEPLOYMENT_INFO_JSON_ON_HPC" \
        --key env_lock "$ENV_LOCK"
}
# We use the TRAP_PRIORITY_BEFORE_LAST trap priority so this step runs right before any cleanup steps (that use TRAP_PRIORITY_LAST)
register_exit_trap_cmd update_hpc_target_deployment_info "$TRAP_PRIORITY_BEFORE_LAST"


### CREATE MANIFEST FILE
# Create a manifest file listing all the files and folders related to the current module version:
# - Modulefile
# - Env activation file
# - Env folder

cat > "$FILES_MANIFEST_PATH" <<EOF
$MODULE_FILE_PATH
$ACTIVATION_SCRIPT_PATH
$APP_VERSION_DIR
EOF

### UPDATE CONTAINER IMAGE
container_image=$(
    get_overrides_or_defaults "$REPO_CONTAINER_IMAGE_PATH" \
    "No container image '${REPO_CONTAINER_IMAGE_PATH#$DEFAULTS_DIR/}' found in the repository's defaults or environment overrides.
    To create it, run the 'build_container_image.yml' repository workflow."
)
copy_if_changed "$container_image" "$RUNTIME_CONTAINER_IMAGE_PATH"
echo "Container image deployed to '$RUNTIME_CONTAINER_IMAGE_PATH'"

### CREATE ENVIRONMENT
echo 'Creating environment within the container...'

# Even though we create the environment in a host working directory, we build the Python environment within the container
# so it's safer for everything to be working as expected once the environment runs within the container itself

# To make sure the paths needed within the container for the environment creation 
# are bound to the host paths, they need to be added to the BIND_STR. 
# This might not be necessary on Gadi, as its singularity configuration automatically 
# binds '/g' and '/scratch' folders, but we add them here anyway for safety.
# We also make sure to bind the temporary directory on the host where the environment
# is created, to the target internal directory where the overlay environment
# will reside (using <host_bound_dir>:<internal_dir>). This ensures that the
# environment is built at the same path it will have at runtime, so the
# squashfs overlay functions correctly.

add_to_bind=(
    "$MAMBA_EXE"
    "$ENV_FILE"
    "$(dirname "$TEMP_ENV_DIR"):$(dirname "$INTERNAL_ENV_DIR")"
)
# Use printf %q for safety with bash special characters like spaces.
add_bind_str=$(printf ",%q" "${add_to_bind[@]}")

# Set host_executables as an array
IFS=',' read -ra host_executables <<< "$HOST_EXECUTABLES"

# Create the environment within the container
"$SINGULARITY_EXE" -s exec \
    --bind "${BIND_STR}${add_bind_str}" \
    "$RUNTIME_CONTAINER_IMAGE_PATH" \
    bash <<EOF

set -euo pipefail
if [[ "${CONTAINERISED_ENVS_DEBUG:-0}" == "1" ]]; then
    set -x
fi

# Print environment specification for debugging purposes
echo 'Creating environment using the following environment specification:'
cat "$ENV_FILE"
echo '' # ensure newline after cat output for readability

# Create the environment
# We use --no-rc to disable the use of configuration files
"$MAMBA_EXE" create -y \
    --prefix "$INTERNAL_ENV_DIR" \
    --file "$ENV_FILE" \
    --no-rc

# Delete executables in host_executables
for exe in "${host_executables[@]}"; do
    rm -vf "$INTERNAL_ENV_BIN_DIR/\$exe"
done

EOF

### CREATE SQUASHFS OVERLAY
echo 'Creating squashfs overlay...'

# The first argument to `mksquashfs` must be the full path to the environment,
# truncated at the directory level that should appear as a subdirectory of the
# container’s root (`/`). We also use `-keep-as-directory` to preserve the final
# directory and ensure the environment ends up at the correct path inside the container
# when the squashfs file is overlaid.
# E.g., if the environment exists at:
# /path/to/current/temp/env/version
# and it should appear inside the container as:
# /temp/env/version
# then `mksquashfs` must be invoked as:
# mksquashfs /path/to/current/temp ... -keep-as-directory

# Get truncated env path (first argument to mksquashfs command)
first_internal_path_portion="${INTERNAL_ENV_DIR#/}"
first_internal_path_portion="${first_internal_path_portion%%/*}"
env_path_truncated="$TEMP_WORKING_DIR/$first_internal_path_portion"

# Set permissions within the squashfs
set_perms "$env_path_truncated"

# Pack the environment into squashfs
mksquashfs "$env_path_truncated" "$TEMP_SQSH_FILE_PATH" \
    -keep-as-directory -no-fragments -no-duplicates -no-sparse \
    -no-exports -no-recovery -no-xattrs -noD -noI -processors 8

# Deploy the squashfs file and set permissions
copy_if_changed "$TEMP_SQSH_FILE_PATH" "$SQSH_FILE_PATH"
set_perms "$SQSH_FILE_PATH"
echo "Squashfs file deployed to '$SQSH_FILE_PATH'"

### DEPLOY MODULE FILES
echo 'Creating module files...'

# Modulefile
modulefile=$(
    get_overrides_or_defaults "$REPO_MODULE_FILE_PATH" \
    "No modulefile '${REPO_MODULE_FILE_PATH#$DEFAULTS_DIR/}' found in the repository's defaults or environment overrides."
)
# Environment activation script
env_activation_script=$(
    get_overrides_or_defaults "$REPO_ACTIVATION_SCRIPT_PATH" \
    "No environment activation script '${REPO_ACTIVATION_SCRIPT_PATH#$DEFAULTS_DIR/}' found in the repository's defaults or environment overrides."
)
# .modulerc
modulerc=$(
    get_overrides_or_defaults "$REPO_MODULERC_FILE_PATH" \
    "No .modulerc file '${REPO_MODULERC_FILE_PATH#$DEFAULTS_DIR/}' found in the repository's defaults or environment overrides."
)

# Deploy module-related files and set permissions
copy_if_changed_with_replace "$env_activation_script" "$ACTIVATION_SCRIPT_PATH"
set_perms "$ACTIVATION_SCRIPT_PATH"
echo "Environment activation script deployed to '$ACTIVATION_SCRIPT_PATH'"

copy_if_changed_with_replace "$modulefile" "$MODULE_FILE_PATH"
set_perms "$MODULE_FILE_PATH"
echo "Module file deployed to '$MODULE_FILE_PATH'"

# Write .modulerc via an EXIT trap so it appears only after the full build
# completes, preventing users from loading a module that isn't ready yet.
# (https://github.com/ACCESS-NRI/containerised-environments-infra/issues/70#issuecomment-4829634066)
create_modulerc() {
    # _exit_status variable is initialised within the register_exit_trap_cmd function
    if [[ "$_exit_status" == 0 ]]; then # Only create .modulerc if the build was successful
        copy_if_changed_with_replace "$modulerc" "$MODULERC_FILE_PATH"
        set_perms "$MODULERC_FILE_PATH"
        echo "Module .modulerc file deployed to '$MODULERC_FILE_PATH'"
    fi
}
register_exit_trap_cmd create_modulerc $TRAP_PRIORITY_FIRST

### COPY LAUNCHER SCRIPT AND LINK BINARIES
# Launcher script
launcher_script=$(
    get_overrides_or_defaults "$REPO_LAUNCHER_SCRIPT_PATH" \
    "No launcher script '${REPO_LAUNCHER_SCRIPT_PATH#$DEFAULTS_DIR/}' found in the repository's defaults or environment overrides."
)

# Deploy launcher script and set permissions
copy_if_changed_with_replace "$launcher_script" "$LAUNCHER_SCRIPT_PATH"
# Add execute permissions to the launcher script
set_perms -x "$LAUNCHER_SCRIPT_PATH"
echo "Launcher script deployed to '$LAUNCHER_SCRIPT_PATH'"

# Create symlinks to the launcher script for all binaries in the environment,
# with exception of those in HOST_EXECUTABLES (that will not be linked)
for binfile in "$TEMP_ENV_DIR"/bin/*; do
    binfile_name=$(basename "$binfile")
    if ! in_array "$binfile_name" "${host_executables[@]}"; then
        ln -s "$LAUNCHER_SCRIPT_PATH" "$ENV_BIN_DIR/$binfile_name"
    fi
done
echo "Environment binaries linked to launcher script"

### GENERATE ENVIRONMENT LOCK
source "$INFRA_SCRIPTS_DIR/generate_env_lock.sh"
echo "Environment lock created to: '$ENV_LOCK_FILE_PATH'"

### CLEANUP OLDEST DEVELOPMENT ENV FOR PRODUCTION
source "$INFRA_SCRIPTS_DIR/cleanup_old_dev_module.sh"

### ENSURE RIGHT PERMISSIONS
set_perms "$APP_VERSION_DIR"

### EXPORT ENV VARIABLES FOR HPC TARGET DEPLOYMENT INFO JSON (update_hpc_target_deployment_info trap function)
# MODULE_USAGE_INSTRUCTIONS
export MODULE_USAGE_INSTRUCTIONS="module use $ALL_MODULES_DIR
module load $MODULE_NAME/$MODULE_VERSION"
# ENV_LOCK
export ENV_LOCK=$(cat "$ENV_LOCK_FILE_PATH")

### RUN DEPLOYMENT POST_SCRIPT
deployment_post_script=$(
    get_overrides_or_defaults "$DEPLOYMENT_POST_SCRIPT_PATH" \
    "No deployment post script '${DEPLOYMENT_POST_SCRIPT_PATH#$DEFAULTS_DIR/}' found in the repository's defaults or environment overrides."
)
source "$deployment_post_script"