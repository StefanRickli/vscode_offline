#!/usr/bin/env bash

# This script patches the vscode-server entrypoint script such that the umask bits
# are inherited from the current user's bash environment

TARGET_FILE="$1"

ANCHOR_LINE='#!/usr/bin/env sh'
PATCH_INDICATOR="# vscode-umask-patch"

set -euo pipefail

grep -Fqx "$PATCH_INDICATOR" "$TARGET_FILE" && {
    echo "Already patched"
    exit 0
}

echo "Patching $TARGET_FILE"

PATCH_CONTENT_FILE="/tmp/vscode-patch"

echo "
#
$PATCH_INDICATOR
# Inherit umask bits from your user's environment
# Fixes https://github.com/microsoft/vscode-remote-release/issues/7902
# Workaround as described here:
# https://github.com/microsoft/vscode-remote-release/issues/4442#issuecomment-3045033587
#" > "$PATCH_CONTENT_FILE"

echo 'umask "$(/usr/bin/env bash -lc umask)"
' >> "$PATCH_CONTENT_FILE"

echo "Backing up original executable"
cp "$TARGET_FILE" "$TARGET_FILE.bak"

escaped_anchor=$(printf '%s\n' "$ANCHOR_LINE" | sed 's/[][\/.^$*]/\\&/g')
sed -i "\|$escaped_anchor|r $PATCH_CONTENT_FILE" "$TARGET_FILE"

rm -f "$PATCH_CONTENT_FILE"

echo "Done."
