#!/usr/bin/env bash
# TACO Hooks System - Automated workflows with pre/post operation hooks

# Initialize hooks system
initialize_hooks() {
    local project_dir="$1"
    
    echo -e "${CYAN}🪝 Initializing Hooks System...${NC}"
    
    # Create hooks directory structure
    mkdir -p "$project_dir/.taco/hooks"
    mkdir -p "$project_dir/.taco/hooks/pre"
    mkdir -p "$project_dir/.taco/hooks/post"
    mkdir -p "$project_dir/.taco/hooks/error"
    
    # Create default hooks
    create_default_hooks "$project_dir"
    
    echo -e "${GREEN}✅ Hooks system initialized${NC}"
}

# Create default hook scripts
create_default_hooks() {
    local project_dir="$1"
    
    # Pre-task hook: Auto-assign agents based on complexity
    cat > "$project_dir/.taco/hooks/pre/auto-assign.sh" << 'EOF'
#!/usr/bin/env bash
# Auto-assign agents based on task complexity

TASK="$1"
COMPLEXITY=$(analyze_task_complexity "$TASK")

case $COMPLEXITY in
    "simple")
        echo "Assigning single Claude agent with standard thinking"
        export TACO_AGENT_COUNT=1
        export THINKING_MODE="standard"
        ;;
    "moderate")
        echo "Assigning 3 parallel agents with think mode"
        export TACO_AGENT_COUNT=3
        export THINKING_MODE="think"
        ;;
    "complex")
        echo "Assigning 5 parallel agents with think harder mode"
        export TACO_AGENT_COUNT=5
        export THINKING_MODE="think harder"
        ;;
    "extreme")
        echo "Assigning 10 parallel agents with ultrathink mode"
        export TACO_AGENT_COUNT=10
        export THINKING_MODE="ultrathink"
        ;;
esac

analyze_task_complexity() {
    local task="$1"
    local keywords_simple="fix bug|add comment|update readme|rename"
    local keywords_moderate="implement feature|add component|create api"
    local keywords_complex="refactor|microservices|architecture|full stack"
    local keywords_extreme="enterprise|distributed|blockchain|ai model"
    
    if echo "$task" | grep -iE "$keywords_extreme" > /dev/null; then
        echo "extreme"
    elif echo "$task" | grep -iE "$keywords_complex" > /dev/null; then
        echo "complex"
    elif echo "$task" | grep -iE "$keywords_moderate" > /dev/null; then
        echo "moderate"
    else
        echo "simple"
    fi
}
EOF
    chmod +x "$project_dir/.taco/hooks/pre/auto-assign.sh"
    
    # Pre-search hook: Cache searches for performance
    cat > "$project_dir/.taco/hooks/pre/cache-search.sh" << 'EOF'
#!/usr/bin/env bash
# Cache search results for improved performance

SEARCH_QUERY="$1"
CACHE_DIR=".taco/cache/searches"
CACHE_FILE="$CACHE_DIR/$(echo "$SEARCH_QUERY" | md5sum | cut -d' ' -f1)"

mkdir -p "$CACHE_DIR"

if [ -f "$CACHE_FILE" ] && [ $(find "$CACHE_FILE" -mmin -15 | wc -l) -gt 0 ]; then
    echo "Using cached search results"
    cat "$CACHE_FILE"
    exit 0
fi

# Perform search and cache results
perform_search "$SEARCH_QUERY" | tee "$CACHE_FILE"
EOF
    chmod +x "$project_dir/.taco/hooks/pre/cache-search.sh"
    
    # Post-task hook: Validate and test
    cat > "$project_dir/.taco/hooks/post/validate.sh" << 'EOF'
#!/usr/bin/env bash
# Validate task completion

TASK_ID="$1"
PROJECT_DIR="$2"

echo "Running post-task validation for task $TASK_ID"

# Run tests
if [ -f "$PROJECT_DIR/package.json" ]; then
    cd "$PROJECT_DIR"
    npm test 2>&1 | tee ".orchestrator/test_results_${TASK_ID}.log"
fi

# Check for linting issues
if command -v eslint > /dev/null; then
    eslint . --format json > ".orchestrator/lint_results_${TASK_ID}.json"
fi

# Validate API endpoints
if [ -f ".orchestrator/connections.json" ]; then
    .orchestrator/validate_connections.sh
fi

# Generate report
generate_validation_report "$TASK_ID"
EOF
    chmod +x "$project_dir/.taco/hooks/post/validate.sh"
    
    # Error hook: Auto-recovery
    cat > "$project_dir/.taco/hooks/error/auto-recovery.sh" << 'EOF'
#!/usr/bin/env bash
# Automatic error recovery

ERROR_TYPE="$1"
AGENT_ID="$2"
ERROR_MSG="$3"

echo "Error detected: $ERROR_TYPE in Agent $AGENT_ID"
echo "Message: $ERROR_MSG"

case $ERROR_TYPE in
    "connection_failed")
        echo "Attempting to restart service..."
        restart_service "$AGENT_ID"
        ;;
    "test_failed")
        echo "Delegating to test-runner sub-agent..."
        delegate_to_subagent "test-runner" "Fix failing test: $ERROR_MSG"
        ;;
    "build_failed")
        echo "Analyzing build error..."
        analyze_build_error "$ERROR_MSG"
        ;;
    "memory_exceeded")
        echo "Clearing cache and restarting agent..."
        clear_agent_cache "$AGENT_ID"
        restart_agent "$AGENT_ID"
        ;;
    *)
        echo "Unknown error type, logging for manual review"
        log_error "$ERROR_TYPE" "$AGENT_ID" "$ERROR_MSG"
        ;;
esac
EOF
    chmod +x "$project_dir/.taco/hooks/error/auto-recovery.sh"
    
    # Performance hook: Monitor and optimize
    cat > "$project_dir/.taco/hooks/performance.sh" << 'EOF'
#!/usr/bin/env bash
# Performance monitoring and optimization

monitor_performance() {
    local project_dir="$1"
    local metrics_file="$project_dir/.orchestrator/metrics.json"
    
    while true; do
        # Collect metrics
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        local mem_usage=$(free -m | awk '/^Mem:/ {print ($3/$2)*100}')
        local agent_count=$(tmux list-windows -t taco 2>/dev/null | wc -l)
        local test_pass_rate=$(calculate_test_pass_rate)
        
        # Write metrics
        cat > "$metrics_file" << JSON
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "cpu_usage": $cpu_usage,
    "memory_usage": $mem_usage,
    "active_agents": $agent_count,
    "test_pass_rate": $test_pass_rate,
    "recommendations": $(generate_recommendations $cpu_usage $mem_usage $agent_count)
}
JSON
        
        # Auto-optimize if needed
        if (( $(echo "$cpu_usage > 80" | bc -l) )); then
            optimize_agent_allocation
        fi
        
        sleep 10
    done
}

optimize_agent_allocation() {
    echo "High CPU usage detected, optimizing agent allocation..."
    # Implement load balancing logic
}
EOF
    chmod +x "$project_dir/.taco/hooks/performance.sh"
}

# Execute hook
execute_hook() {
    local hook_type="$1"  # pre, post, error
    local hook_name="$2"
    local project_dir="$3"
    shift 3
    local args="$@"
    
    local hook_script="$project_dir/.taco/hooks/$hook_type/$hook_name.sh"
    
    if [ -f "$hook_script" ]; then
        echo -e "${CYAN}🪝 Executing $hook_type hook: $hook_name${NC}"
        bash "$hook_script" $args
        local result=$?
        
        if [ $result -eq 0 ]; then
            echo -e "${GREEN}✅ Hook executed successfully${NC}"
        else
            echo -e "${RED}❌ Hook failed with code $result${NC}"
        fi
        
        return $result
    fi
    
    return 0
}

# Register custom hook
register_hook() {
    local project_dir="$1"
    local hook_type="$2"
    local hook_name="$3"
    local hook_script="$4"
    
    local target_dir="$project_dir/.taco/hooks/$hook_type"
    mkdir -p "$target_dir"
    
    cp "$hook_script" "$target_dir/$hook_name.sh"
    chmod +x "$target_dir/$hook_name.sh"
    
    echo -e "${GREEN}✅ Hook registered: $hook_type/$hook_name${NC}"
}

# List all hooks
list_hooks() {
    local project_dir="$1"
    
    echo -e "${CYAN}📋 Registered Hooks:${NC}"
    echo "===================="
    
    for type in pre post error; do
        echo -e "\n${YELLOW}$type hooks:${NC}"
        if [ -d "$project_dir/.taco/hooks/$type" ]; then
            ls -1 "$project_dir/.taco/hooks/$type/"*.sh 2>/dev/null | while read hook; do
                echo "  - $(basename "$hook" .sh)"
            done
        fi
    done
}

# Hook chain execution
execute_hook_chain() {
    local project_dir="$1"
    local chain_name="$2"
    shift 2
    local args="$@"
    
    local chain_file="$project_dir/.taco/hooks/chains/$chain_name.json"
    
    if [ -f "$chain_file" ]; then
        echo -e "${CYAN}🔗 Executing hook chain: $chain_name${NC}"
        
        # Parse and execute hooks in sequence
        jq -r '.hooks[]' "$chain_file" | while read hook_def; do
            local type=$(echo "$hook_def" | jq -r '.type')
            local name=$(echo "$hook_def" | jq -r '.name')
            local continue_on_error=$(echo "$hook_def" | jq -r '.continue_on_error // false')
            
            execute_hook "$type" "$name" "$project_dir" $args
            local result=$?
            
            if [ $result -ne 0 ] && [ "$continue_on_error" != "true" ]; then
                echo -e "${RED}Hook chain aborted due to error${NC}"
                return $result
            fi
        done
        
        echo -e "${GREEN}✅ Hook chain completed${NC}"
    else
        echo -e "${YELLOW}Hook chain not found: $chain_name${NC}"
    fi
}

# Create hook chain
create_hook_chain() {
    local project_dir="$1"
    local chain_name="$2"
    
    mkdir -p "$project_dir/.taco/hooks/chains"
    
    cat > "$project_dir/.taco/hooks/chains/$chain_name.json" << EOF
{
    "name": "$chain_name",
    "description": "Custom hook chain",
    "hooks": [
        {"type": "pre", "name": "auto-assign", "continue_on_error": false},
        {"type": "pre", "name": "cache-search", "continue_on_error": true},
        {"type": "post", "name": "validate", "continue_on_error": false}
    ]
}
EOF
    
    echo -e "${GREEN}✅ Hook chain created: $chain_name${NC}"
}