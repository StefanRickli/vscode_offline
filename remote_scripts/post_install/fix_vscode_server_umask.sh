#!/bin/bash

# We patch the `code-server` script to mitigate behavior as documented here:
# https://github.com/microsoft/vscode-remote-release/issues/7902
# Workaround as described here:
# https://github.com/microsoft/vscode-remote-release/issues/4442#issuecomment-3045033587

set -euo pipefail

# Define the regex for X and Z
regex_x="umask"
regex_z="server-main\.js"
line_y="umask 002"

file=$(find . -name "code-server")
file_path=$(realpath "$file")

if [ ! -f "$file_path" ]; then
    echo "Could not find code-server binary"
    exit 1
fi

echo "Patching '$file_path'..."

# Check if a line matching regex_x exists in the file
if ! grep -qP "$regex_x" "$file_path"; then
    # If line X is found, check for line Z
    if grep -qP "$regex_z" "$file_path"; then
        # Use sed to insert line Y before line Z
        sed -i "/$regex_z/i $line_y" "$file_path"
        echo "'$line_y' inserted before line that matches '$regex_z'"
    else
        echo "Could not find marker line pattern '$regex_z'!"
        exit 1
    fi
else
    echo "File already patched."
fi
