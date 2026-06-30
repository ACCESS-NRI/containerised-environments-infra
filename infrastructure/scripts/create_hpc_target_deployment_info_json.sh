# This script produces a JSON file containing deployment information
# for a specific HPC target.
# The values for the JSON file fields are taken from the following env variables:
#
# - HPC_TARGET
# - MODULE_NAME
# - MODULE_VERSION
# - MODULE_TYPE
# - DEPLOYMENT_STAGE
# - STARTED_AT
# - SUCCESS
#
# When SUCCESS is "true", the following env vars must also be set:
# - MODULE_USAGE_INSTRUCTIONS
# - FILES_MANIFEST_PATH
# - COMPLETED_AT
#
#
# Usage:
#   create_hpc_target_deployment_info_json.sh [--key KEY VALUE]... OUTPUT_JSON_FILE

set -u

usage() {
    cat <<'EOF'
Usage:
  create_hpc_target_deployment_info_json.sh [--key KEY VALUE]... OUTPUT_JSON_FILE

Description:
  Creates an HPC target deployment JSON file from environment variables.
  Additional deployment fields can be added by providing any number of `--key KEY VALUE` arguments.
EOF
}

file=""
declare -a extra_keys=()
declare -a extra_values=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --key)
            if [[ $# -lt 3 ]]; then
                echo "Error: --key requires KEY and VALUE arguments" >&2
                usage
                exit 1
            fi
            extra_keys+=("$2")
            extra_values+=("$3")
            shift 3
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Error: unknown option '$1'" >&2
            usage
            exit 1
            ;;
        *)
            if [[ -n "$file" ]]; then
                echo "Error: multiple output files provided ('$file', '$1')" >&2
                usage
                exit 1
            fi
            file="$1"
            shift
            ;;
    esac
done

if [[ -z "$file" ]]; then
    echo "Error: missing OUTPUT_JSON_FILE argument" >&2
    usage
    exit 1
fi

deployment_json="$("$JQ_EXE" -n \
    --arg target "$HPC_TARGET" \
    --arg name "$MODULE_NAME" \
    --arg version "$MODULE_VERSION" \
    --arg type "$MODULE_TYPE" \
    --arg stage "$DEPLOYMENT_STAGE" \
    --arg started_at "$STARTED_AT" \
    --arg success "$SUCCESS" \
    '{
        "name": $target,
        "deployments": [
            {
                "module_name": $name,
                "module_version": $version,
                "module_type": $type,
                "deployment_stage": $stage,
                "started_at": $started_at,
                "success": $success
            }
        ]
    }')"

# Add keys if SUCCESS is true
if [[ $SUCCESS == true ]]; then
    files_manifest_content="$(<"$FILES_MANIFEST_PATH")"
    deployment_json="$(printf '%s' "$deployment_json" | "$JQ_EXE" \
        --arg completed_at "$COMPLETED_AT" \
        --arg module_usage_instructions "$MODULE_USAGE_INSTRUCTIONS" \
        --arg files_manifest "$files_manifest_content" \
        '.deployments[0].completed_at = $completed_at
         | .deployments[0].module_usage_instructions = $module_usage_instructions
         | .deployments[0].files_manifest = $files_manifest')"
fi

reserved_keys_regex='^(module_name|module_version|module_type|deployment_stage|started_at|completed_at|module_usage_instructions|files_manifest|success)$'
for i in "${!extra_keys[@]}"; do
    key="${extra_keys[$i]}"
    value="${extra_values[$i]}"

    if [[ -z "$key" ]]; then
        echo "Error: key name cannot be empty" >&2
        exit 1
    fi

    if [[ "$key" =~ $reserved_keys_regex ]]; then
        echo "Error: key '$key' is a default deployment field and cannot be set with --key" >&2
        exit 1
    fi

    deployment_json="$(printf '%s' "$deployment_json" | "$JQ_EXE" --arg k "$key" --arg v "$value" '.deployments[0][$k] = $v')"
done

printf '%s\n' "$deployment_json" > "$file"