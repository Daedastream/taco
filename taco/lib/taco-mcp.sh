#!/usr/bin/env bash
# TACO MCP (Model Context Protocol) Integration
# Connects Claude to external tools and services

# Initialize MCP servers
initialize_mcp_servers() {
    local project_dir="$1"
    local settings_file="${2:-$TACO_HOME/config/taco.settings.json}"
    
    echo -e "${CYAN}🔌 Initializing MCP Servers...${NC}"
    
    # Create MCP configuration directory
    mkdir -p "$project_dir/.taco/mcp"
    
    # Parse enabled MCP servers from settings
    local mcp_servers=$(jq -r '.communication.mcp_servers[]' "$settings_file" 2>/dev/null)
    
    for server in $mcp_servers; do
        case $server in
            "filesystem")
                setup_filesystem_mcp "$project_dir"
                ;;
            "git")
                setup_git_mcp "$project_dir"
                ;;
            "docker")
                setup_docker_mcp "$project_dir"
                ;;
            "kubernetes")
                setup_kubernetes_mcp "$project_dir"
                ;;
            "postgres")
                setup_postgres_mcp "$project_dir"
                ;;
            "redis")
                setup_redis_mcp "$project_dir"
                ;;
            "playwright")
                setup_playwright_mcp "$project_dir"
                ;;
            "linear")
                setup_linear_mcp "$project_dir"
                ;;
            *)
                echo -e "${YELLOW}Unknown MCP server: $server${NC}"
                ;;
        esac
    done
    
    echo -e "${GREEN}✅ MCP servers initialized${NC}"
}

# Setup filesystem MCP server
setup_filesystem_mcp() {
    local project_dir="$1"
    cat > "$project_dir/.taco/mcp/filesystem.json" << EOF
{
    "name": "filesystem",
    "type": "builtin",
    "enabled": true,
    "config": {
        "root": "$project_dir",
        "permissions": "read-write",
        "watch": true
    }
}
EOF
}

# Setup Git MCP server
setup_git_mcp() {
    local project_dir="$1"
    cat > "$project_dir/.taco/mcp/git.json" << EOF
{
    "name": "git",
    "type": "builtin",
    "enabled": true,
    "config": {
        "repo": "$project_dir",
        "auto_commit": false,
        "branch_protection": true
    }
}
EOF
}

# Setup Docker MCP server
setup_docker_mcp() {
    local project_dir="$1"
    cat > "$project_dir/.taco/mcp/docker.json" << EOF
{
    "name": "docker",
    "type": "external",
    "enabled": true,
    "executable": "mcp-docker",
    "config": {
        "socket": "/var/run/docker.sock",
        "compose_file": "$project_dir/docker-compose.yml",
        "auto_build": true
    }
}
EOF
}

# Setup Kubernetes MCP server
setup_kubernetes_mcp() {
    local project_dir="$1"
    cat > "$project_dir/.taco/mcp/kubernetes.json" << EOF
{
    "name": "kubernetes",
    "type": "external",
    "enabled": true,
    "executable": "mcp-k8s",
    "config": {
        "kubeconfig": "~/.kube/config",
        "namespace": "default",
        "manifests": "$project_dir/k8s/"
    }
}
EOF
}

# Setup PostgreSQL MCP server
setup_postgres_mcp() {
    local project_dir="$1"
    cat > "$project_dir/.taco/mcp/postgres.json" << EOF
{
    "name": "postgres",
    "type": "external",
    "enabled": true,
    "executable": "mcp-postgres",
    "config": {
        "connection_string": "\${DATABASE_URL}",
        "migrations": "$project_dir/migrations/",
        "auto_migrate": false
    }
}
EOF
}

# Setup Redis MCP server
setup_redis_mcp() {
    local project_dir="$1"
    cat > "$project_dir/.taco/mcp/redis.json" << EOF
{
    "name": "redis",
    "type": "external",
    "enabled": true,
    "executable": "mcp-redis",
    "config": {
        "host": "localhost",
        "port": 6379,
        "db": 0
    }
}
EOF
}

# Setup Playwright MCP for browser testing
setup_playwright_mcp() {
    local project_dir="$1"
    cat > "$project_dir/.taco/mcp/playwright.json" << EOF
{
    "name": "playwright",
    "type": "external",
    "enabled": true,
    "executable": "mcp-playwright",
    "config": {
        "headless": true,
        "browsers": ["chromium", "firefox", "webkit"],
        "test_dir": "$project_dir/e2e/"
    }
}
EOF
}

# Setup Linear MCP for issue tracking
setup_linear_mcp() {
    local project_dir="$1"
    cat > "$project_dir/.taco/mcp/linear.json" << EOF
{
    "name": "linear",
    "type": "external",
    "enabled": true,
    "executable": "mcp-linear",
    "config": {
        "api_key": "\${LINEAR_API_KEY}",
        "team_id": "\${LINEAR_TEAM_ID}",
        "auto_create_issues": true
    }
}
EOF
}

# Launch Claude with MCP servers
launch_claude_with_mcp() {
    local project_dir="$1"
    local prompt="$2"
    local mcp_config="$project_dir/.taco/mcp"
    
    # Build MCP server list
    local mcp_args=""
    for config in "$mcp_config"/*.json; do
        if [ -f "$config" ]; then
            local enabled=$(jq -r '.enabled' "$config")
            if [ "$enabled" = "true" ]; then
                local name=$(jq -r '.name' "$config")
                mcp_args="$mcp_args --mcp-server $name"
            fi
        fi
    done
    
    # Launch Claude with MCP servers
    echo -e "${CYAN}Launching Claude with MCP servers: $mcp_args${NC}"
    cd "$project_dir"
    claude $mcp_args --continue "$prompt"
}

# Monitor MCP server activity
monitor_mcp_activity() {
    local project_dir="$1"
    local log_file="$project_dir/.orchestrator/mcp.log"
    
    echo -e "${CYAN}📊 MCP Activity Monitor${NC}"
    echo "=========================="
    
    while true; do
        if [ -f "$log_file" ]; then
            tail -n 20 "$log_file" | while read -r line; do
                if [[ "$line" =~ "ERROR" ]]; then
                    echo -e "${RED}$line${NC}"
                elif [[ "$line" =~ "SUCCESS" ]]; then
                    echo -e "${GREEN}$line${NC}"
                else
                    echo "$line"
                fi
            done
        fi
        sleep 2
        clear
        echo -e "${CYAN}📊 MCP Activity Monitor${NC}"
        echo "=========================="
    done
}

# Bridge MCP with TACO's orchestration
bridge_mcp_orchestration() {
    local project_dir="$1"
    
    # Create bridge script
    cat > "$project_dir/.orchestrator/mcp_bridge.sh" << 'EOF'
#!/usr/bin/env bash
# Bridge MCP servers with TACO orchestration

# Forward MCP events to TACO monitoring
forward_mcp_events() {
    local event="$1"
    local data="$2"
    
    echo "[MCP] $event: $data" >> .orchestrator/orchestrator.log
    
    # Broadcast to agents if needed
    if [[ "$event" =~ "critical" ]]; then
        .orchestrator/message_relay.sh "[MCP ALERT] $data"
    fi
}

# Sync MCP state with TACO registry
sync_mcp_state() {
    while true; do
        # Update connection registry with MCP services
        for service in .taco/mcp/*.json; do
            if [ -f "$service" ]; then
                local name=$(jq -r '.name' "$service")
                local status=$(jq -r '.status // "unknown"' "$service")
                
                # Update registry
                jq --arg name "$name" --arg status "$status" \
                    '.mcp_services[$name] = $status' \
                    .orchestrator/connections.json > .orchestrator/connections.tmp
                mv .orchestrator/connections.tmp .orchestrator/connections.json
            fi
        done
        sleep 5
    done
}

# Main
sync_mcp_state &
EOF
    chmod +x "$project_dir/.orchestrator/mcp_bridge.sh"
}

# Create MCP-aware Claude context
create_mcp_claude_context() {
    local project_dir="$1"
    local prompt="$2"
    
    cat > "$project_dir/CLAUDE_MCP.md" << EOF
# MCP-Enhanced Claude Context

## Available MCP Servers
$(ls -1 "$project_dir/.taco/mcp/"*.json 2>/dev/null | xargs -I {} basename {} .json | sed 's/^/- /')

## MCP Capabilities
- Direct filesystem access via MCP
- Git operations without bash
- Docker container management
- Database queries and migrations
- Redis cache operations
- Browser automation with Playwright
- Issue tracking with Linear

## Usage Instructions
1. MCP servers are automatically available
2. Use them directly without bash commands when possible
3. MCP operations are faster and more reliable
4. All MCP actions are logged to .orchestrator/mcp.log

## Project Goal
$prompt

## Coordination
- Use MCP for infrastructure operations
- Use sub-agents for code generation
- Use TACO orchestration for parallel execution
EOF
}