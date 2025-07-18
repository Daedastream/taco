#!/usr/bin/env bash
# TACO Installation Script

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🌮 Installing TACO - Tmux Agent Command Orchestrator${NC}"
echo

# Check for required dependencies
check_dependency() {
    local cmd="$1"
    local install_msg="$2"
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${RED}❌ Missing dependency: $cmd${NC}"
        echo -e "${YELLOW}   $install_msg${NC}"
        return 1
    fi
    return 0
}

echo "Checking dependencies..."
missing_deps=0

if ! check_dependency "tmux" "Install with: brew install tmux (macOS) or apt-get install tmux (Linux)"; then
    missing_deps=$((missing_deps + 1))
fi

if ! check_dependency "claude" "Install Claude CLI from Anthropic"; then
    missing_deps=$((missing_deps + 1))
fi

if ! check_dependency "jq" "Install with: brew install jq (macOS) or apt-get install jq (Linux)"; then
    echo -e "${YELLOW}⚠️  Optional dependency jq not found. Some features may be limited.${NC}"
fi

if [ $missing_deps -gt 0 ]; then
    echo -e "${RED}❌ Please install missing dependencies before continuing.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All required dependencies found${NC}"
echo

# Determine installation directory
if [ -n "$PREFIX" ]; then
    INSTALL_PREFIX="$PREFIX"
elif [ -w "/usr/local" ]; then
    INSTALL_PREFIX="/usr/local"
else
    INSTALL_PREFIX="$HOME/.local"
fi

echo -e "${YELLOW}Installing to: $INSTALL_PREFIX${NC}"
echo

# Create directories
echo "Creating directories..."
mkdir -p "$INSTALL_PREFIX/bin"
mkdir -p "$INSTALL_PREFIX/share/taco"
mkdir -p "$INSTALL_PREFIX/share/taco/lib"
mkdir -p "$INSTALL_PREFIX/share/taco/docs"

# Copy files
echo "Installing TACO..."
cp -r taco/lib/* "$INSTALL_PREFIX/share/taco/lib/"
cp taco/bin/taco "$INSTALL_PREFIX/bin/"

# Update the taco script to use the installed location
sed -i.bak "s|TACO_HOME=.*|TACO_HOME=\"$INSTALL_PREFIX/share/taco\"|" "$INSTALL_PREFIX/bin/taco"
rm "$INSTALL_PREFIX/bin/taco.bak"

# Make executable
chmod +x "$INSTALL_PREFIX/bin/taco"

# Create uninstall script
cat > "$INSTALL_PREFIX/share/taco/uninstall.sh" << EOF
#!/usr/bin/env bash
# TACO Uninstall Script

echo "Removing TACO..."
rm -f "$INSTALL_PREFIX/bin/taco"
rm -rf "$INSTALL_PREFIX/share/taco"
echo "TACO has been uninstalled."
EOF
chmod +x "$INSTALL_PREFIX/share/taco/uninstall.sh"

# Add to PATH if needed
if [[ ":$PATH:" != *":$INSTALL_PREFIX/bin:"* ]]; then
    echo
    echo -e "${YELLOW}Add the following to your shell configuration (.bashrc, .zshrc, etc.):${NC}"
    echo -e "${GREEN}export PATH=\"$INSTALL_PREFIX/bin:\$PATH\"${NC}"
fi

echo
echo -e "${GREEN}✅ TACO installed successfully!${NC}"
echo
echo "To get started:"
echo "  1. Ensure $INSTALL_PREFIX/bin is in your PATH"
echo "  2. Run: taco --help"
echo
echo "To uninstall:"
echo "  Run: $INSTALL_PREFIX/share/taco/uninstall.sh"
echo