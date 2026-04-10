#!/usr/bin/env bash

# Robustly extract the function from the source file
# We look for the function start and end by markers or context
# In this case, we know it's in dot_config/zsh/dot_zshenv
# We'll use sed to extract it.

SOURCE_FILE="dot_config/zsh/dot_zshenv"

# Extract the function block
# We look for _zb_path_prepend() { ... }
# Note: This is a bit fragile if the function structure changes,
# but better than copying the code.
eval "$(sed -n '/_zb_path_prepend() {/,/^}/p' "$SOURCE_FILE")"

# Verify the function was loaded
if ! declare -f _zb_path_prepend > /dev/null; then
    echo "ERROR: Failed to extract _zb_path_prepend from $SOURCE_FILE"
    exit 1
fi

test_path_prepend() {
    local initial_path="$1"
    local to_add="$2"
    local expected_path="$3"
    local description="$4"

    export PATH="$initial_path"
    _zb_path_prepend "$to_add"

    if [ "$PATH" = "$expected_path" ]; then
        echo "PASS: $description"
    else
        echo "FAIL: $description"
        echo "  Initial:  '$initial_path'"
        echo "  To add:   '$to_add'"
        echo "  Expected: '$expected_path'"
        echo "  Actual:   '$PATH'"
        return 1
    fi
}

errors=0

echo "Running tests for _zb_path_prepend using actual source..."

# Test cases for prepend behavior
test_path_prepend "" "/usr/local/bin" "/usr/local/bin" "Empty PATH" || errors=$((errors+1))
test_path_prepend "/usr/bin:/bin" "/usr/local/bin" "/usr/local/bin:/usr/bin:/bin" "Normal prepend" || errors=$((errors+1))
test_path_prepend "/usr/bin:/bin" "/bin" "/usr/bin:/bin" "Already in PATH (end)" || errors=$((errors+1))
test_path_prepend "/usr/bin:/bin" "/usr/bin" "/usr/bin:/bin" "Already in PATH (start)" || errors=$((errors+1))
test_path_prepend "/usr/local/bin:/usr/bin:/bin" "/usr/bin" "/usr/local/bin:/usr/bin:/bin" "Already in PATH (middle)" || errors=$((errors+1))
test_path_prepend "/usr/bin:/bin" "/usr" "/usr:/usr/bin:/bin" "Substring (should add)" || errors=$((errors+1))
test_path_prepend "/usr/bin:/bin" "/usr/bin.old" "/usr/bin.old:/usr/bin:/bin" "Similar name (should add)" || errors=$((errors+1))
test_path_prepend "/usr/bin:/bin" "" "/usr/bin:/bin" "Add empty string (should do nothing)" || errors=$((errors+1))
test_path_prepend "/usr/bin::/bin" "/usr/local/bin" "/usr/local/bin:/usr/bin::/bin" "Multiple consecutive colons" || errors=$((errors+1))

if [ $errors -eq 0 ]; then
    echo "All tests passed using actual source."
else
    echo "$errors tests failed."
fi

exit $errors
