#!/usr/bin/env bash
# TACO Installation Script

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🌮 Installing TACO v2.0 - Tmux Agent Command Orchestrator${NC}"
echo -e "${CYAN}Now with Claude Sub-Agents, MCP, and Multi-Model Support!${NC}"
echo

# Create user config directory
mkdir -p "$HOME/.taco"

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

# Claude is optional now - we support multiple agents
if ! check_dependency "claude" "Install Claude CLI from Anthropic (optional)"; then
    echo -e "${YELLOW}⚠️  Claude not found. You can still use other agents (OpenAI, Llama, etc.)${NC}"
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
mkdir -p "$INSTALL_PREFIX/share/taco/config"

# Copy files
echo "Installing TACO v2.0..."
cp -r taco/lib/* "$INSTALL_PREFIX/share/taco/lib/"
cp -r taco/config "$INSTALL_PREFIX/share/taco/" 2>/dev/null || mkdir -p "$INSTALL_PREFIX/share/taco/config"
cp taco/bin/taco "$INSTALL_PREFIX/bin/"

# Copy new v2.0 files
if [ -f taco/config/taco.settings.json ]; then
    cp taco/config/taco.settings.json "$INSTALL_PREFIX/share/taco/config/"
fi

# Create examples directory
mkdir -p "$INSTALL_PREFIX/share/taco/examples"
if [ -d examples ]; then
    cp -r examples/* "$INSTALL_PREFIX/share/taco/examples/" 2>/dev/null || true
fi

# Update the taco script to use the installed location
sed -i.bak "s|TACO_HOME=.*|TACO_HOME=\"$INSTALL_PREFIX/share/taco\"|" "$INSTALL_PREFIX/bin/taco"
rm "$INSTALL_PREFIX/bin/taco.bak"

# Make executable
chmod +x "$INSTALL_PREFIX/bin/taco"

# Install Python dependencies for API agents (optional)
echo ""
echo "Optional: Install Python dependencies for API agents?"
read -r -p "Install anthropic, openai, mistralai packages? (y/n): " install_python

if [ "$install_python" = "y" ]; then
    echo "Installing Python packages..."
    pip install anthropic openai mistralai google-generativeai 2>/dev/null || \
    pip3 install anthropic openai mistralai google-generativeai 2>/dev/null || \
    echo -e "${YELLOW}⚠️  Could not install Python packages. Install manually if needed.${NC}"
fi

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
echo -e "${GREEN}✅ TACO v2.0 installed successfully!${NC}"
echo
echo "To get started:"
echo "  1. Ensure $INSTALL_PREFIX/bin is in your PATH"
echo "  2. Configure settings: taco --configure"
echo "  3. Run: taco --help"
echo ""
echo "New in v2.0:"
echo "  • Claude Sub-Agents with /agents command"
echo "  • MCP (Model Context Protocol) support"
echo "  • Multi-model orchestration (GPT-4, Gemini, Llama, etc.)"
echo "  • Advanced hooks system"
echo "  • Hybrid orchestration mode"
echo "  • Settings management via JSON"
echo
echo "To uninstall:"
echo "  Run: $INSTALL_PREFIX/share/taco/uninstall.sh"
echo