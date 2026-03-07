#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check dependencies
missing=()
for cmd in tmux jq envsubst claude; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
done

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Warning: missing dependencies: ${missing[*]}"
    echo "See README.md for install instructions."
    echo ""
fi

# Install taco via symlink (keeps templates resolution working)
echo "Installing taco to $INSTALL_DIR..."

if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "Error: $INSTALL_DIR does not exist."
    echo "Set INSTALL_DIR to a different path: INSTALL_DIR=~/.local/bin ./install.sh"
    exit 1
fi

if [[ ! -w "$INSTALL_DIR" ]]; then
    echo "Need sudo to write to $INSTALL_DIR"
    sudo ln -sf "$SCRIPT_DIR/taco" "$INSTALL_DIR/taco"
else
    ln -sf "$SCRIPT_DIR/taco" "$INSTALL_DIR/taco"
fi

echo "Done. Symlinked $INSTALL_DIR/taco -> $SCRIPT_DIR/taco"
echo ""
echo "Run 'taco' to get started."
