# This script is used to write a bash script that exports the environment variables
# needed for the deploy process on the HPC system.

# The bash variables in this script are taken from the GitHub job environment 
# defined within the deploy_module.yml workflow.

# Path to the infrastructure scripts directory within the repository
infra_scripts_dir="$REPO_PATH/infrastructure/scripts"

# write export script
cat <<EOF
export CONTAINERISED_ENVS_DEBUG=$CONTAINERISED_ENVS_DEBUG
export TEMP_EXCHANGE_DIR='$TEMP_EXCHANGE_DIR'
export STABLE_PRODUCTION_BASE_DIR='$STABLE_PRODUCTION_BASE_DIR'
export REPO_PATH='$REPO_PATH'
export INFRA_SCRIPTS_DIR='$infra_scripts_dir'
export GROUP_OWNER='$GROUP_OWNER'
export PBS_PROJECT='$PBS_PROJECT'
export PBS_STORAGE='$PBS_STORAGE'
export SINGULARITY_EXE='$SINGULARITY_EXE'
export JQ_EXE='$JQ_EXE'
export MODULE_NAME='$MODULE_NAME'
export MODULE_VERSION='$MODULE_VERSION'
export MODULE_TYPE='$MODULE_TYPE'
export HPC_TARGET='$HPC_TARGET'
export HPC_NAME='$HPC_NAME'
export DEPLOYMENT_INFO_JSON_ON_HPC='$DEPLOYMENT_INFO_JSON_ON_HPC'
export STARTED_AT='$STARTED_AT'
export PAYU_TELEMETRY_CONFIG_PATH='$PAYU_TELEMETRY_CONFIG_PATH'
export DEPLOYMENT_WORKFLOW_RUN_ID='$DEPLOYMENT_WORKFLOW_RUN_ID'
export DEPLOYMENT_WORKFLOW_URL='$DEPLOYMENT_WORKFLOW_URL'
export COMMIT_SHA='$COMMIT_SHA'
EOF
