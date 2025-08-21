#!/usr/bin/env bash
# Test script for TACO v2.0 features

echo "🧪 TACO v2.0 Feature Test"
echo "========================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test results
PASSED=0
FAILED=0

# Test function
test_feature() {
    local name="$1"
    local command="$2"
    
    echo -n "Testing $name... "
    if eval "$command" 2>/dev/null; then
        echo -e "${GREEN}✅ PASSED${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}❌ FAILED${NC}"
        FAILED=$((FAILED + 1))
    fi
}

# Test 1: Check installation
test_feature "TACO installation" "[ -f ~/.local/bin/taco ]"

# Test 2: Check new library files
test_feature "Claude sub-agents module" "[ -f taco/lib/taco-claude-subagents.sh ]"
test_feature "Hybrid mode module" "[ -f taco/lib/taco-hybrid-mode.sh ]"
test_feature "MCP module" "[ -f taco/lib/taco-mcp.sh ]"
test_feature "Hooks module" "[ -f taco/lib/taco-hooks.sh ]"
test_feature "Settings module" "[ -f taco/lib/taco-settings.sh ]"
test_feature "Multi-agent module" "[ -f taco/lib/taco-multi-agent.sh ]"

# Test 3: Check settings file
test_feature "Settings JSON" "[ -f taco/config/taco.settings.json ]"

# Test 4: Check examples
test_feature "Netflix example" "[ -f examples/netflix-clone-comparison.md ]"

# Test 5: Validate settings JSON
test_feature "Valid settings JSON" "jq empty taco/config/taco.settings.json"

# Test 6: Check upgrade docs
test_feature "Upgrade documentation" "[ -f UPGRADE_TO_V2.md ]"

# Test 7: Check TACO executable
if [ -f ~/.local/bin/taco ]; then
    test_feature "TACO is executable" "[ -x ~/.local/bin/taco ]"
fi

# Summary
echo ""
echo "========================"
echo "Test Results:"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed! TACO v2.0 is ready to use.${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Add to PATH: export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo "2. Configure: taco --configure"
    echo "3. Try it: taco --hybrid"
else
    echo -e "\n${YELLOW}⚠️  Some tests failed. Please check the installation.${NC}"
fi