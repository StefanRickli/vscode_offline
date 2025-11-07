#!/bin/bash

set -euo pipefail

remote_temp_dir="$1"
vscode_server_archive="$2"
target_bin_dir="$3"

if ! sudo -v; then
    echo "It seems like you cannot sudo without password. This is a prerequisite. Abort."
    exit 1
fi

echo "Creating directory '$target_bin_dir' ..."
mkdir -p "$target_bin_dir"

echo "Copying VS Code Server binary into '$target_bin_dir'..."
tar xf "$remote_temp_dir/$vscode_server_archive" -C "$target_bin_dir" --strip-components=1

echo "Creating entries in /etc/hosts (if not present)..."
sudo sed -i '/[[:space:]]mobile.events.data.microsoft.com$/d' /etc/hosts
echo '8.8.8.8 mobile.events.data.microsoft.com' | sudo tee -a /etc/hosts >/dev/null
sudo sed -i '/[[:space:]]marketplace.visualstudio.com$/d' /etc/hosts
echo '8.8.8.8 marketplace.visualstudio.com' | sudo tee -a /etc/hosts >/dev/null

cd "$target_bin_dir"

echo "Running Post-Install Scripts..."
for script in "$remote_temp_dir"/*.sh; do
    chmod +x "$script"
    # Exclude the current script to avoid recursions
    if [ $(basename $0) = $(basename "$script") ]; then continue; fi
    echo "Running: $script"
    bash "$script"
done
