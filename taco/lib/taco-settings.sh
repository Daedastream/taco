#!/usr/bin/env bash
# TACO Settings Management

# Load settings from JSON file
load_taco_settings() {
    local settings_file="${SETTINGS_FILE:-$TACO_HOME/config/taco.settings.json}"
    local silent_mode="${1:-false}"
    
    if [ ! -f "$settings_file" ]; then
        settings_file="$HOME/.taco/settings.json"
    fi
    
    if [ ! -f "$settings_file" ]; then
        if [ "$silent_mode" != "true" ]; then
            echo -e "${YELLOW}⚠️  No settings file found, using defaults${NC}"
        fi
        return
    fi
    
    # Only show messages if not in silent mode
    if [ "$silent_mode" != "true" ]; then
        echo -e "${BLUE}🌮 TACO v2.0.0${NC}"
        echo -e "${CYAN}📋 Loading settings from: $settings_file${NC}"
    fi
    
    # Export settings as environment variables
    export TACO_VERSION=$(jq -r '.version' "$settings_file" 2>/dev/null || echo "2.0.0")
    export TACO_MODE=$(jq -r '.orchestration.mode' "$settings_file" 2>/dev/null || echo "hybrid")
    export TACO_PARALLEL=$(jq -r '.orchestration.parallel_execution' "$settings_file" 2>/dev/null || echo "true")
    export TACO_MAX_AGENTS=$(jq -r '.orchestration.max_agents' "$settings_file" 2>/dev/null || echo "20")
    export TACO_DEFAULT_AGENT=$(jq -r '.orchestration.default_agent_type' "$settings_file" 2>/dev/null || echo "claude")
    export TACO_CLAUDE_MODEL=$(jq -r '.orchestration.claude_model' "$settings_file" 2>/dev/null || echo "sonnet")
    
    # Communication settings
    export TACO_PROTOCOL=$(jq -r '.communication.protocol' "$settings_file" 2>/dev/null || echo "enhanced")
    export TACO_MCP_ENABLED=$(jq -r '.communication.mcp_enabled' "$settings_file" 2>/dev/null || echo "true")
    export TACO_MESSAGE_FORMAT=$(jq -r '.communication.message_format' "$settings_file" 2>/dev/null || echo "json")
    
    # Agent settings
    export TACO_SUB_AGENTS_ENABLED=$(jq -r '.agents.claude.sub_agents_enabled' "$settings_file" 2>/dev/null || echo "true")
    export TACO_CACHE_PROMPTS=$(jq -r '.agents.claude.cache_prompts' "$settings_file" 2>/dev/null || echo "true")
    export TACO_HEADLESS=$(jq -r '.agents.claude.headless_mode' "$settings_file" 2>/dev/null || echo "false")
    
    # Testing settings
    export TACO_TEST_MANDATORY=$(jq -r '.testing.mandatory' "$settings_file" 2>/dev/null || echo "true")
    export TACO_MIN_COVERAGE=$(jq -r '.testing.min_coverage' "$settings_file" 2>/dev/null || echo "80")
    
    # Performance settings
    export TACO_MEMORY_LIMIT=$(jq -r '.performance.memory_limit' "$settings_file" 2>/dev/null || echo "4GB")
    export TACO_GPU_ENABLED=$(jq -r '.performance.gpu_enabled' "$settings_file" 2>/dev/null || echo "false")
    
    if [ "$silent_mode" != "true" ]; then
        echo -e "${GREEN}✅ Settings loaded${NC}"
    fi
}

# Save current settings
save_taco_settings() {
    local settings_file="${1:-$HOME/.taco/settings.json}"
    mkdir -p "$(dirname "$settings_file")"
    
    cat > "$settings_file" << EOF
{
    "version": "${TACO_VERSION:-2.0.0}",
    "orchestration": {
        "mode": "${TACO_MODE:-hybrid}",
        "parallel_execution": ${TACO_PARALLEL:-true},
        "max_agents": ${TACO_MAX_AGENTS:-20},
        "default_agent_type": "${TACO_DEFAULT_AGENT:-claude}",
        "claude_model": "${TACO_CLAUDE_MODEL:-sonnet}"
    },
    "communication": {
        "protocol": "${TACO_PROTOCOL:-enhanced}",
        "mcp_enabled": ${TACO_MCP_ENABLED:-true},
        "message_format": "${TACO_MESSAGE_FORMAT:-json}"
    },
    "modified": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    echo -e "${GREEN}✅ Settings saved to: $settings_file${NC}"
}

# Interactive settings configuration
configure_settings_interactive() {
    echo -e "${CYAN}⚙️  TACO Settings Configuration${NC}"
    echo "================================"
    
    # Orchestration mode
    echo -e "\n${YELLOW}Orchestration Mode:${NC}"
    echo "1. Hybrid (Claude sub-agents + parallel execution)"
    echo "2. Classic (tmux agents only)"
    echo "3. Sequential (one agent at a time)"
    read -r -p "Choose mode (1-3, default 1): " mode_choice
    
    case $mode_choice in
        2) TACO_MODE="classic" ;;
        3) TACO_MODE="sequential" ;;
        *) TACO_MODE="hybrid" ;;
    esac
    
    # Default agent
    echo -e "\n${YELLOW}Default Agent Type:${NC}"
    echo "1. Claude"
    echo "2. OpenAI GPT-4"
    echo "3. Anthropic API"
    echo "4. Local Llama"
    echo "5. Gemini"
    read -r -p "Choose agent (1-5, default 1): " agent_choice
    
    case $agent_choice in
        2) TACO_DEFAULT_AGENT="openai" ;;
        3) TACO_DEFAULT_AGENT="anthropic_api" ;;
        4) TACO_DEFAULT_AGENT="llama" ;;
        5) TACO_DEFAULT_AGENT="gemini" ;;
        *) TACO_DEFAULT_AGENT="claude" ;;
    esac
    
    # Claude model selection (if using Claude)
    if [ "$TACO_DEFAULT_AGENT" = "claude" ]; then
        echo -e "\n${YELLOW}Claude Model:${NC}"
        echo "1. Sonnet (faster, default)"
        echo "2. Opus (more capable)"
        read -r -p "Choose model (1-2, default 1): " model_choice
        
        case $model_choice in
            2) TACO_CLAUDE_MODEL="opus" ;;
            *) TACO_CLAUDE_MODEL="sonnet" ;;
        esac
    fi
    
    # MCP servers
    echo -e "\n${YELLOW}Enable MCP servers? (y/n, default y):${NC}"
    read -r -p "> " mcp_choice
    [ "$mcp_choice" = "n" ] && TACO_MCP_ENABLED="false" || TACO_MCP_ENABLED="true"
    
    # Sub-agents
    echo -e "\n${YELLOW}Enable Claude sub-agents? (y/n, default y):${NC}"
    read -r -p "> " subagent_choice
    [ "$subagent_choice" = "n" ] && TACO_SUB_AGENTS_ENABLED="false" || TACO_SUB_AGENTS_ENABLED="true"
    
    # Max parallel agents
    echo -e "\n${YELLOW}Maximum parallel agents (1-20, default 10):${NC}"
    read -r -p "> " max_agents
    TACO_MAX_AGENTS="${max_agents:-10}"
    
    # Save settings
    save_taco_settings
}

# Validate settings
validate_settings() {
    local settings_file="${1:-$TACO_HOME/config/taco.settings.json}"
    
    if [ ! -f "$settings_file" ]; then
        echo -e "${RED}❌ Settings file not found: $settings_file${NC}"
        return 1
    fi
    
    # Validate JSON syntax
    if ! jq empty "$settings_file" 2>/dev/null; then
        echo -e "${RED}❌ Invalid JSON in settings file${NC}"
        return 1
    fi
    
    # Validate required fields
    local version=$(jq -r '.version' "$settings_file")
    if [ -z "$version" ] || [ "$version" = "null" ]; then
        echo -e "${RED}❌ Missing version in settings${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Settings validation passed${NC}"
    return 0
}

# Export settings to agents
export_settings_to_agents() {
    local project_dir="$1"
    local settings_file="${2:-$TACO_HOME/config/taco.settings.json}"
    
    # Create agent-specific settings
    for window in $(seq 3 10); do
        local agent_settings="$project_dir/.taco/agent_${window}_settings.json"
        
        # Extract agent-specific settings
        jq --arg window "$window" '
            {
                agent_id: $window,
                global: .orchestration,
                communication: .communication,
                testing: .testing,
                performance: .performance
            }
        ' "$settings_file" > "$agent_settings"
    done
    
    echo -e "${GREEN}✅ Settings exported to all agents${NC}"
}

# Merge user settings with defaults
merge_settings() {
    local user_settings="$1"
    local default_settings="$2"
    local output_file="$3"
    
    # Merge using jq
    jq -s '.[0] * .[1]' "$default_settings" "$user_settings" > "$output_file"
    
    echo -e "${GREEN}✅ Settings merged${NC}"
}

# Settings migration for upgrades
migrate_settings() {
    local old_version="$1"
    local new_version="$2"
    local settings_file="$3"
    
    echo -e "${CYAN}🔄 Migrating settings from v$old_version to v$new_version${NC}"
    
    case "$old_version" in
        "1.0.0"|"1.1.0"|"1.2.0")
            # Migrate from v1.x to v2.0
            echo "Adding new v2.0 features..."
            jq '. + {
                "agents": {
                    "claude": {
                        "sub_agents_enabled": true,
                        "thinking_modes": {},
                        "hooks": {}
                    }
                },
                "memory": {
                    "type": "sqlite",
                    "semantic_search": true
                },
                "advanced": {
                    "swarm_intelligence": true
                }
            }' "$settings_file" > "${settings_file}.tmp"
            mv "${settings_file}.tmp" "$settings_file"
            ;;
    esac
    
    # Update version
    jq --arg version "$new_version" '.version = $version' "$settings_file" > "${settings_file}.tmp"
    mv "${settings_file}.tmp" "$settings_file"
    
    echo -e "${GREEN}✅ Settings migrated to v$new_version${NC}"
}