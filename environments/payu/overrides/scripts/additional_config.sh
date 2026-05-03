# This script is sourced at the end of the `install_config.sh` script to define additional
# custom environment variables for the deployment.
# If you want to replace the default values of some environment variables used for the deployment,
# use the `default_config.sh` script instead.

# If the deployment is for STAGING, set PAYU_TELEMETRY_CONFIG_PATH to an empty string
if [[ "$DEPLOYMENT_STAGE" == STAGING ]]; then
  PAYU_TELEMETRY_CONFIG_PATH=
fi