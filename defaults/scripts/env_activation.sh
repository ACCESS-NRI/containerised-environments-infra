# The double underscore variables within this file are replaced by the 'replace_dunder_variables'
# function within the build.sh or deploy.sh scripts

env_path='__INTERNAL_ENV_DIR__'
env_bin_path='__INTERNAL_ENV_BIN_DIR__'

# Prepend path with continerised environment bin directory
export PATH="$env_bin_path:$PATH"
# Set CONDA_DEFAULT_ENV
export CONDA_DEFAULT_ENV="$env_path"
# The following environment variables are also set in the modulefile, but we set them here as well
# so they are always set correctly within the internal environment, even if the module is not loaded
# (e.g., if an environment executable is run using its full path without loading the module)
export CONDA_PREFIX="$env_path"
export CONDA_PROMPT_MODIFIER='__ENV_PROMPT_MODIFIER__'

for file in "$env_path"/etc/conda/activate.d/*.sh; do
    if [ -r "$file" ]; then
        . "$file"
    fi
done
