# This script is used to write a bash script that exports the environment variables
# needed for the deploy process on the HPC system.

# The bash variables in this script are taken from the GitHub job environment 
# defined within the deploy_env.yml workflow.

set -euo pipefail

if [[ "${CONTAINERISED_ENVS_DEBUG:-0}" == "1" ]]; then
    set -x
fi

# Strip slash from STABLE_PRODUCTION_BASE_DIR
STABLE_PRODUCTION_BASE_DIR=${STABLE_PRODUCTION_BASE_DIR%/}
# Path to default files within the repository
defaults_dir="$REPO_PATH/defaults"
# Path to the scripts wihtin the default files
scripts_dir="$defaults_dir/scripts"
# Path to the infrastructure scripts directory
infra_scripts_dir="$REPO_PATH/infrastructure/scripts"
# Path to the admin directory
admin_dir="$STABLE_PRODUCTION_BASE_DIR/admin"
# Name of the development subdirectory
development_subdir_name=prerelease
# Path to the directory where development modules for production are deployed
development_production_base_dir="$STABLE_PRODUCTION_BASE_DIR/$development_subdir_name"
# Path to the directory where stable modules for staging are deployed
stable_staging_base_dir="$admin_dir/staging"
# Path to the directory where development modules for staging are deployed
development_staging_base_dir="$admin_dir/staging/$development_subdir_name"
# Path to the logs directory
logs_dir="$admin_dir/logs"
# Path to the install config file
install_config="$infra_scripts_dir/install_config.sh"
# Name for the containerised environments root dir
containerised_envs_root_dir_name=containerised_envs
# Name of the directory where all apps will be stored
apps_dir_name=apps
# Name of the directory where all modules will be stored
modules_dir_name=modules
# Path to the functions script
functions_path="$infra_scripts_dir/functions.sh"

# write export script
cat <<EOF
export GROUP_OWNER='$GROUP_OWNER'
export PBS_PROJECT='$PBS_PROJECT'
export PBS_STORAGE='$PBS_STORAGE'
export SINGULARITY_EXE='$SINGULARITY_EXE'
export JQ_EXE='$JQ_EXE'
export STABLE_PRODUCTION_BASE_DIR='$STABLE_PRODUCTION_BASE_DIR'
export CONTAINERISED_ENVS_DEBUG=$CONTAINERISED_ENVS_DEBUG
export REPO_PATH='$REPO_PATH'
export MODULE_NAME='$MODULE_NAME'
export MODULE_VERSION='$MODULE_VERSION'
export MODULE_TYPE='$MODULE_TYPE'
export HPC_TARGET='$HPC_TARGET'
export HPC_TARGET_DEPLOYMENT_INFO_JSON_PATH='$HPC_TARGET_DEPLOYMENT_INFO_JSON_PATH'
export STARTED_AT='$STARTED_AT'
export DEFAULTS_DIR='$defaults_dir'
export SCRIPTS_DIR='$scripts_dir'
export INFRA_SCRIPTS_DIR='$infra_scripts_dir'
export ADMIN_DIR='$admin_dir'
export DEVELOPMENT_PRODUCTION_BASE_DIR='$development_production_base_dir'
export STABLE_STAGING_BASE_DIR='$stable_staging_base_dir'
export DEVELOPMENT_STAGING_BASE_DIR='$development_staging_base_dir'
export LOGS_DIR='$logs_dir'
export INSTALL_CONFIG='$install_config'
export CONTAINERISED_ENVS_ROOT_DIR_NAME='$containerised_envs_root_dir_name'
export APPS_DIR_NAME='$apps_dir_name'
export MODULES_DIR_NAME='$modules_dir_name'
export FUNCTIONS_PATH='$functions_path'
export PAYU_TELEMETRY_CONFIG_PATH='$PAYU_TELEMETRY_CONFIG_PATH'
EOF
