### Useful functions

# Associative array for register_exit_trap_cmd function. 
# key -> value: priority -> command(s)
declare -A _trap_queue

# Accessory function to register_exit_trap_cmd
function _build_trap_cmds() {
    # We set the '_exit_status' variable at the beginning of the combined trapped commands to
    # capture the exit status of the EXIT signal.
    # This is needed because we cannot simply use `$?` directly within a command passed to
    # register_exit_trap_cmd because that would capture the exit status of the previous command
    # executed, which might be another command passed to register_exit_trap_cmd and not be the
    # original exit status of the script.
    # This way the '_exit_status' variable is available for all commands passed to 
    # register_exit_trap_cmd to refer to the original exit status of the script.
    local combined_cmds priority trap_cmd
    
    combined_cmds='_exit_status=$? ; '
    combined_cmds+='echo "========================================================" ; '
    combined_cmds+='echo "BEGINNING OF EXIT TRAPPED COMMANDS" ; '
    combined_cmds+='echo "========================================================" ; '

    # Sort _trap_queue keys (priority) numerically and build the command chain in order of priority.
    # If any registered EXIT command fails and the original exit status (_exit_status) was 0, promote it to 1
    for priority in $(echo "${!_trap_queue[@]}" | tr ' ' '\n' | sort -n); do
        while IFS= read -r trap_cmd; do
            [[ -z "$trap_cmd" ]] && continue
            combined_cmds+="if ! { $trap_cmd ; }; then "
            combined_cmds+='if [[ "$_exit_status" -eq 0 ]]; then _exit_status=1; fi ; '
            combined_cmds+="fi ; "
        done <<< "${_trap_queue[$priority]}"
    done
    # Exit with the $_exit_status
    combined_cmds+='exit "$_exit_status"'
    trap "$combined_cmds" EXIT
}

function register_exit_trap_cmd() {
    # Register a command to be executed when the EXIT signal is triggered, with a priority level
    # that determines the order of execution relative to other registered commands.
    # Lower priority numbers run first, higher numbers run last.
    # Commands with the same priority run in registration order.
    # The commands registered are executed using `trap CMDs EXIT`, where CMDs is the combination
    # of all registered commands in the correct priority order.
    # 
    # Usage: register_exit_trap_cmd CMD [PRIORITY]
    #   CMD      - The command to run when the EXIT signal is triggered
    #   PRIORITY - Integer number defininig the execution order (default: 50). 
    #              Lower runs first, higher runs last.
    #
    # Note: to refer to the exit status of the script within trap commands, use
    # `$_exit_status` instead of `$?`, as `$?` will reflect the exit status of the
    # previously executed trap command rather than the original script exit status.
    #
    # If any trap command fails and $_exit_status is 0, $_exit_status will be 
    # updated to 1.
    # The exit code of the whole EXIT registered commands will be `$_exit_status`.
    #
    # Examples:
    #   register_exit_trap_cmd "my_fun"
    #   register_exit_trap_cmd "remove_fun" 90
    #   register_exit_trap_cmd "some_fun" 10
    #   register_exit_trap_cmd "my_other_fun"
    #
    #   will be executed as `trap 'some_fun ; my_fun ; my_other_fun ; remove_fun ; ' EXIT`
    local cmd priority
    
    cmd="$1"
    priority="${2:-50}"  # default priority 50, lower runs first
    
    # Add the command to the trap queue with the specified priority
    if [[ -v _trap_queue["$priority"] ]]; then
        _trap_queue["$priority"]+=$'\n'"$cmd"
    else
        _trap_queue["$priority"]="$cmd"
    fi

    # Build the trap command based on the registered commands and their priorities
    _build_trap_cmds
}

function is_in_array() {
    # Search an item in an array.
    # Assumes first arg as the item to search for and the others are the array
    local string item
    string="$1"
    shift
    for item in "$@"; do
        [[ "$item" == "$string" ]] && return 0
    done
    return 1
}

function add_to_files_manifest() {
    # Add a file or directory to the files manifest for the current module version.
    # If the file or directory is already listed in the manifest, it will not be added again.
    local path
    path="$1"
    if [[ ! -e "$path" ]]; then
        echo "Path '$path' not found." >&2
        return 1
    fi
    touch "$FILES_MANIFEST_PATH"
    if ! grep -Fqx -- "$path" "$FILES_MANIFEST_PATH"; then
        echo "$path" >> "$FILES_MANIFEST_PATH"
    fi
}

function delete_files_in_manifest() {
    # Delete all files and folders associated with a version, which are listed in the manifest $1.
    local manifest_file="$1"
    if [[ ! -f "$manifest_file" ]]; then
        echo "Error: manifest file '$manifest_file' not found." >&2
        return 1
    fi
    # Make sure to split the manifest by newlines and not by spaces (-d '\n')
    # Do not run if the manifest is empty (--no-run-if-empty)
    xargs --no-run-if-empty -d '\n' rm -vrf < "$manifest_file"
}

function set_perms() {
    # Set permissions to a provided file or directory (recursively).
    # Use the -x option to set executable permissions to files.

    local OPTIND OPTARG opt default_exec_perm exec_perm arg acls
    
    # Default permission to capital X, to set executable permissions to files only
    # if any user already has executable permissions
    default_exec_perm='X'
    while getopts ":x" opt; do
        case $opt in
            x) exec_perm=x ;;
            \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
        esac
    done
    shift $((OPTIND - 1))
    arg="$1"

    # Change group owner of files and directories recursively
    # we use the -h option to change symbolic links themselves and not the link they point to
    chgrp -R -h "$GROUP_OWNER" "$arg"

    # reset ACLs to make sure we don't have any non-wanted ACLs
    setfacl -R -b "$arg"

    ### Directories
    # Define permissions
    acls='u::rwx' # rwx for user
    acls+=',g::r-x' # r-x for group
    acls+=',o::---' # no permissions for others
    # Define default permissions
    # (newly created files/folders within the directory will inherit these permissions)
    acls+=',d:u::rwx' # rwx for user
    acls+=',d:g::r-x' # r-x for group
    acls+=',d:o::---' # no permissions for others
    # Set permissions and setgid (newly created files/folders will inherit the group owner of the directory)
    find "$arg" -type d \
        -exec setfacl -m "$acls" {} + \
        -exec chmod g+s {} +
    
    ### Files
    # Define permissions
    acls="u::rw${exec_perm:-$default_exec_perm}" # rwx for user if -x option is provided, otherwise rwX
    acls+=",g::r-${exec_perm:-$default_exec_perm}" # r-x for group if -x option is provided, otherwise r-X
    acls+=",o::---" # no permissions for others
    # Set permissions
    find "$arg" -type f \
        -exec setfacl -m "$acls" {} +
}

function copy_if_changed() {
    # Copy the file at $1 to $2 only if the destination doesn't exist or differs.
    # Behavior:
    # 1. If $2 is a directory: copy $1 into $2 using $1's basename if missing or different.
    # 2. If $2 is a file: copy $1 over it if contents differ.
    # 3. If $2 doesn't exist but its parent directory exists: copy $1 to $2's location.

    local src dest target parent_dir 
    src="$1"
    dest="$2"

    if [ -d "$dest" ]; then
        # Destination is a directory: copy into it using $1's basename
        target="$dest/$(basename "$src")"
    else
        # Destination is a file or doesn't exist: copy to that path
        target="$dest"
    fi
    # Ensure the parent directory exists before copying
    parent_dir=$(dirname "$target")
    if [ ! -d "$parent_dir" ]; then
        echo "Error: trying to copy to '$target' but parent directory '$parent_dir' does not exist" >&2
        return 1
    fi

    # Copy only if missing or contents differ
    if [ ! -e "$target" ]; then
        cp "$src" "$target"
        echo "Created '$target'"
    elif ! cmp -s "$src" "$target"; then
        cp "$src" "$target"
        echo "Updated '$target'"
    fi
}

function _replace_dunder_variables() {
    # Replace the double underscore (dunder) variables in $1 with values from the environment,
    # and outputs the replaced content.
    # E.g. "__MY_VAR__" is replaced with the value of MY_VAR. 
    # If a variable that should have been replaced is not found, an error is thrown.
    # !!IMPORTANT!! dunder variables within commented lines are replaced too!
    local file content vars var name value
    file="$1"
    # Read the file content into a variable to be modified without modifying the file
    content=$(<"$file")
    # Catch all unique variables to replace
    vars=$(grep -oE '__[A-Z0-9_]+__' "$file" | sort -u)
    for var in $vars; do
        # Remove double undescores
        name="${var#__}"
        name="${name%__}"
        if [[ -z "${!name+x}" ]]; then
            # If the variable is not defined in the environment raise an error
            echo "Error: environment variable '$name' to replace within '$file' is not defined" >&2
            return 1
        fi
        value="${!name}"
        # Escape characters in 'value' that are special sed replacements characters to avoid problems
        # in the replacements.
        # Sed special characters are `&`, `\` and the character we choose as sed command delimiter (`|`)
        # Also, within this value replacement command, we use `/` as a sed delimiter so the command is
        # clearer as we don't have to escape the `|` character. We also have to escape the backslash (`\\`)
        value=$(printf '%s' "$value" | sed 's/[&|\\]/\\&/g')
        # Replace characters (using `|` as a sed delimiter as mentioned above)
        content=$(printf '%s' "$content" | sed "s|$var|$value|g")
    done
    # Output the final modified content
    printf '%s' "$content"
}

function copy_if_changed_with_replace() {
    # Replace the double underscore (dunder) variables in $1 with values from the environment
    # E.g. "__MY_VAR__" is replaced with the value of MY_VAR. 
    # If a variable that should have been replaced is not found, an error is thrown.
    # Then, copy the replaced version of $1 to $2, but only if $2 doesn't exist 
    # or content of the replaced $1 is different from $2

    local tmpdir tmpfile
    # Create a temporary file to store the replaced $1
    # We create a temporary directory and then we set the filename within
    # because we need the filename to be exactly the same as $1.
    tmpdir=$(mktemp -d)
    # Clean up temporary directory on exit
    register_exit_trap_cmd "rm -vrf $tmpdir" $TRAP_PRIORITY_LAST
    # Set the temporary file path within the temporary directory with the same basename as $1
    tmpfile="$tmpdir/$(basename "$1")"
    # Store the replaced version of $1 in a the file
    _replace_dunder_variables "$1" > "$tmpfile"
    # Copy the replaced version of $1 to $2
    copy_if_changed "$tmpfile" "$2"
}

function get_overrides_or_defaults() {
    # This function checks for the existence of a correspondent override file for the default $1. 
    # If an override file exists, it returns its path. Otherwise, it returns $1.
    # $2 is used to provide an error message.

    local file overrides_file
    
    file="$1"

    # Get override file path by replacing the $DEFAULTS_DIR part of the default file path with $ENV_OVERRIDES_DIR
    overrides_file="${file/#$DEFAULTS_DIR/$ENV_OVERRIDES_DIR}"

    # If the overrides file exists, we use it, otherwise we use the default file. 
    # If neither of them exists, we raise an error.
    if [[ -f "$overrides_file" ]]; then
        file="$overrides_file"
    elif [[ ! -f "$file" ]]; then
        echo "$2" >&2
        exit 1
    fi
    printf '%s' "$file"
}