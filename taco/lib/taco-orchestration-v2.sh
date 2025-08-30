#!/usr/bin/env bash
# TACO v2.0 Enhanced Orchestration with Full Claude Features
# Includes /memory, dependency graph, parallel execution, and communication protocol

# Initialize Claude memory for persistent context
initialize_claude_memory() {
    local project_dir="$1"
    local memory_file="$project_dir/.taco/memory/claude_memory.json"
    
    mkdir -p "$project_dir/.taco/memory"
    
    # Create initial memory structure
    cat > "$memory_file" << 'EOF'
{
    "project_context": {
        "name": "",
        "description": "",
        "start_time": "",
        "architecture_decisions": [],
        "key_components": [],
        "dependencies": {},
        "test_results": [],
        "performance_metrics": {}
    },
    "agent_memories": {},
    "shared_knowledge": {
        "api_endpoints": [],
        "database_schemas": [],
        "business_rules": [],
        "error_patterns": [],
        "optimization_history": []
    },
    "dependency_graph": {
        "nodes": [],
        "edges": [],
        "execution_order": []
    }
}
EOF
    
    echo -e "${GREEN}✅ Claude memory system initialized${NC}"
}

# Enhanced agent specification with dependency graph
create_enhanced_specification() {
    local user_request="$1"
    local count_instruction="$2"
    
    cat << 'EOF'
🚨 ENHANCED SPECIFICATION MODE WITH DEPENDENCY GRAPH 🚨

You must create a COMPLETE dependency graph for parallel execution.

PROJECT: $user_request

Required Output Format:
AGENT_SPEC_START
AGENT:window:name:role:type(optional)
DEPENDS_ON:comma,separated,dependencies
NOTIFIES:comma,separated,targets
WAIT_FOR:comma,separated,prerequisites
MEMORY_SHARE:comma,separated,agents
PARALLEL_WITH:comma,separated,agents
[repeat for all agents]
AGENT_SPEC_END

Dependency Rules:
- DEPENDS_ON: Agents that must complete before this one starts
- NOTIFIES: Agents to notify when this one completes
- WAIT_FOR: Specific tasks to wait for
- MEMORY_SHARE: Agents that share memory context
- PARALLEL_WITH: Agents that can run simultaneously

Example for a web app:
AGENT_SPEC_START
AGENT:3:frontend:React UI developer:claude
DEPENDS_ON:none
NOTIFIES:testing
WAIT_FOR:none
MEMORY_SHARE:backend,testing
PARALLEL_WITH:backend,database

AGENT:4:backend:API developer:claude
DEPENDS_ON:database
NOTIFIES:frontend,testing
WAIT_FOR:schema_ready
MEMORY_SHARE:frontend,database,testing
PARALLEL_WITH:frontend

AGENT:5:database:Database architect:claude
DEPENDS_ON:none
NOTIFIES:backend
WAIT_FOR:none
MEMORY_SHARE:backend
PARALLEL_WITH:frontend

AGENT:6:testing:Test engineer:claude
DEPENDS_ON:frontend,backend
NOTIFIES:deployment
WAIT_FOR:api_ready,ui_ready
MEMORY_SHARE:all
PARALLEL_WITH:none

AGENT:7:deployment:DevOps engineer:claude
DEPENDS_ON:testing
NOTIFIES:none
WAIT_FOR:tests_passing
MEMORY_SHARE:none
PARALLEL_WITH:none
AGENT_SPEC_END

CREATE YOUR SPECIFICATION NOW WITH FULL DEPENDENCY GRAPH!
EOF
}

# Parse and build dependency graph
build_dependency_graph() {
    local spec_file="$1"
    local graph_file="$2"
    
    echo -e "${CYAN}📊 Building dependency graph...${NC}"
    
    # Initialize graph structure
    cat > "$graph_file" << 'EOF'
{
    "nodes": {},
    "edges": [],
    "execution_phases": [],
    "parallel_groups": {}
}
EOF
    
    # Parse agent specifications
    while IFS= read -r line; do
        if [[ "$line" =~ ^AGENT:([0-9]+):([^:]+):([^:]+):?([^:]*)$ ]]; then
            local window="${BASH_REMATCH[1]}"
            local name="${BASH_REMATCH[2]}"
            local role="${BASH_REMATCH[3]}"
            local type="${BASH_REMATCH[4]:-claude}"
            
            # Add node to graph
            jq --arg w "$window" --arg n "$name" --arg r "$role" --arg t "$type" \
                '.nodes[$n] = {window: $w, role: $r, type: $t, status: "pending"}' \
                "$graph_file" > "$graph_file.tmp" && mv "$graph_file.tmp" "$graph_file"
        elif [[ "$line" =~ ^DEPENDS_ON:(.*)$ ]]; then
            local deps="${BASH_REMATCH[1]}"
            # Add dependencies to current node
        elif [[ "$line" =~ ^PARALLEL_WITH:(.*)$ ]]; then
            local parallel="${BASH_REMATCH[1]}"
            # Group parallel agents
        fi
    done < "$spec_file"
    
    # Calculate execution phases based on dependencies
    calculate_execution_phases "$graph_file"
    
    echo -e "${GREEN}✅ Dependency graph built${NC}"
}

# Calculate optimal execution phases
calculate_execution_phases() {
    local graph_file="$1"
    
    # Topological sort to determine execution order
    # Phase 1: No dependencies (can start immediately)
    # Phase 2: Depends only on Phase 1
    # Phase 3: Depends on Phase 1 or 2
    # etc.
    
    echo -e "${CYAN}Calculating parallel execution phases...${NC}"
    
    # This would use the actual dependency data to create phases
    # For now, showing the structure:
    jq '.execution_phases = [
        {
            "phase": 1,
            "agents": ["frontend", "database"],
            "parallel": true
        },
        {
            "phase": 2,
            "agents": ["backend"],
            "parallel": false
        },
        {
            "phase": 3,
            "agents": ["testing"],
            "parallel": false
        }
    ]' "$graph_file" > "$graph_file.tmp" && mv "$graph_file.tmp" "$graph_file"
}

# Enhanced coordination with memory and communication
coordinate_with_memory() {
    local project_dir="$1"
    local memory_file="$project_dir/.taco/memory/claude_memory.json"
    local graph_file="$project_dir/.taco/dependency_graph.json"
    
    cat << 'EOF'
=== ENHANCED COORDINATION WITH MEMORY AND DEPENDENCIES ===

You are the Mother Orchestrator with access to:
1. Shared memory system (/memory command)
2. Dependency graph for parallel execution
3. Inter-agent communication protocol
4. Real-time status monitoring

CRITICAL CLAUDE FEATURES TO USE:

1. MEMORY COMMANDS:
   /memory add "key" "value"     - Store shared information
   /memory get "key"             - Retrieve information
   /memory list                  - Show all memory
   /memory share agent_name      - Share memory with specific agent

2. SUB-AGENTS:
   /agents create name "description"  - Create specialized sub-agent
   /agents invoke name "task"         - Delegate to sub-agent
   /agents list                       - Show all sub-agents

3. THINKING MODES:
   - Use "think" for moderate complexity
   - Use "think harder" for architecture decisions
   - Use "ultrathink" for critical problems

4. COMMUNICATION PROTOCOL:
   a. Check dependency graph before starting agents
   b. Start agents in parallel phases
   c. Use message relay for coordination
   d. Update shared memory with progress
   e. Monitor test results continuously

EXECUTION FLOW:

Phase 1: Initialize
- Load dependency graph
- Initialize shared memory
- Create sub-agents for each main agent

Phase 2: Parallel Execution
- Start all Phase 1 agents (no dependencies)
- Monitor their progress via memory
- When Phase 1 completes, start Phase 2
- Continue through all phases

Phase 3: Coordination
- Use message relay for inter-agent communication
- Update shared memory with API endpoints, schemas, etc.
- Ensure dependencies are met before progression

Phase 4: Validation
- All agents must report completion
- Test results must be passing
- Deploy only after all checks pass

EXAMPLE COORDINATION:

```bash
# Start Phase 1 agents (frontend, database) in parallel
tmux send-keys -t taco:3 "/memory add phase 'starting' && /agents create react-expert 'React specialist'"
tmux send-keys -t taco:5 "/memory add phase 'starting' && create schema"

# Wait for Phase 1 completion
/memory get frontend_status
/memory get database_status

# Start Phase 2 (backend) after dependencies met
tmux send-keys -t taco:4 "/memory get database_schema && build API"

# Share progress continuously
/memory add api_endpoints "[GET /users, POST /auth/login]"
/memory share testing  # Share with testing agent
```

BEGIN COORDINATION WITH FULL FEATURE UTILIZATION!
EOF
}

# Launch agents with memory and dependencies
launch_agents_with_dependencies() {
    local project_dir="$1"
    local graph_file="$project_dir/.taco/dependency_graph.json"
    
    echo -e "${CYAN}🚀 Launching agents based on dependency graph...${NC}"
    
    # Read execution phases
    local phases=$(jq -r '.execution_phases | length' "$graph_file")
    
    for ((phase=1; phase<=phases; phase++)); do
        echo -e "${YELLOW}Starting Phase $phase...${NC}"
        
        # Get agents for this phase
        local agents=$(jq -r ".execution_phases[$((phase-1))].agents[]" "$graph_file")
        
        for agent in $agents; do
            local window=$(jq -r ".nodes.\"$agent\".window" "$graph_file")
            local type=$(jq -r ".nodes.\"$agent\".type" "$graph_file")
            local role=$(jq -r ".nodes.\"$agent\".role" "$graph_file")
            
            echo -e "${GREEN}Launching $agent (window $window)...${NC}"
            
            # Launch with memory initialization
            tmux send-keys -t "taco:$window" "cd $project_dir/$agent" Enter
            sleep 0.2
            
            # Initialize Claude with memory
            # Use the configured Claude model (default: sonnet)
            local model_flag=""
            if [ -n "$TACO_CLAUDE_MODEL" ]; then
                model_flag="--model $TACO_CLAUDE_MODEL"
            fi
            tmux send-keys -t "taco:$window" "claude --continue $model_flag" Enter
            sleep 0.5
            
            # Set up memory context
            tmux send-keys -t "taco:$window" "/memory add agent_name '$agent'" Enter
            sleep 0.2
            tmux send-keys -t "taco:$window" "/memory add role '$role'" Enter
            sleep 0.2
            tmux send-keys -t "taco:$window" "/memory add phase '$phase'" Enter
            sleep 0.2
            
            # Create relevant sub-agents
            case $agent in
                frontend)
                    tmux send-keys -t "taco:$window" "/agents create react-expert 'React and hooks specialist'" Enter
                    tmux send-keys -t "taco:$window" "/agents create css-expert 'CSS and responsive design'" Enter
                    ;;
                backend)
                    tmux send-keys -t "taco:$window" "/agents create api-architect 'REST and GraphQL design'" Enter
                    tmux send-keys -t "taco:$window" "/agents create auth-expert 'Authentication and security'" Enter
                    ;;
                testing)
                    tmux send-keys -t "taco:$window" "/agents create unit-tester 'Unit test specialist'" Enter
                    tmux send-keys -t "taco:$window" "/agents create e2e-tester 'End-to-end test expert'" Enter
                    ;;
            esac
            
            # Send initial task
            tmux send-keys -t "taco:$window" "Begin working on $role. Check /memory list for shared context." Enter
        done
        
        # Wait for phase completion if not parallel
        if [ "$phase" -lt "$phases" ]; then
            echo -e "${YELLOW}Waiting for Phase $phase to complete...${NC}"
            monitor_phase_completion "$project_dir" "$phase"
        fi
    done
    
    echo -e "${GREEN}✅ All agents launched according to dependency graph${NC}"
}

# Monitor phase completion
monitor_phase_completion() {
    local project_dir="$1"
    local phase="$2"
    local memory_file="$project_dir/.taco/memory/claude_memory.json"
    
    while true; do
        # Check if all agents in phase are complete
        local all_complete=true
        
        # Check memory for completion status
        local phase_status=$(jq -r ".project_context.phase_${phase}_complete" "$memory_file" 2>/dev/null)
        
        if [ "$phase_status" = "true" ]; then
            echo -e "${GREEN}✅ Phase $phase complete${NC}"
            break
        fi
        
        sleep 5
    done
}

# Real-time communication relay with memory updates
enhanced_message_relay() {
    local project_dir="$1"
    local sender="$2"
    local recipient="$3"
    local message="$4"
    
    # Log to communication log
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$sender → $recipient]: $message" >> "$project_dir/.orchestrator/communication.log"
    
    # Update shared memory
    local memory_key="${sender}_to_${recipient}_$(date +%s)"
    jq --arg key "$memory_key" --arg msg "$message" \
        '.shared_knowledge.messages[$key] = $msg' \
        "$project_dir/.taco/memory/claude_memory.json" > \
        "$project_dir/.taco/memory/claude_memory.json.tmp" && \
        mv "$project_dir/.taco/memory/claude_memory.json.tmp" \
        "$project_dir/.taco/memory/claude_memory.json"
    
    # Send to recipient's tmux window
    local recipient_window=$(jq -r ".nodes.\"$recipient\".window" "$project_dir/.taco/dependency_graph.json")
    
    if [ -n "$recipient_window" ]; then
        tmux send-keys -t "taco:$recipient_window" "/memory get ${sender}_message" Enter
        sleep 0.2
        tmux send-keys -t "taco:$recipient_window" "# Message from $sender: $message" Enter
    fi
}

# Complete orchestration flow
execute_orchestration_v2() {
    local project_dir="$1"
    local user_request="$2"
    
    echo -e "${CYAN}🎭 TACO v2.0 Enhanced Orchestration Starting...${NC}"
    
    # Step 1: Initialize systems
    initialize_claude_memory "$project_dir"
    
    # Step 2: Get agent specification with dependencies
    echo -e "${YELLOW}Requesting agent specification...${NC}"
    local spec_prompt=$(create_enhanced_specification "$user_request" "")
    # This would be sent to Mother Claude to get the specification
    
    # Step 3: Build dependency graph
    build_dependency_graph "$project_dir/.orchestrator/agent_spec.txt" \
                          "$project_dir/.taco/dependency_graph.json"
    
    # Step 4: Launch agents with dependencies
    launch_agents_with_dependencies "$project_dir"
    
    # Step 5: Monitor and coordinate
    echo -e "${CYAN}📡 Monitoring agent coordination...${NC}"
    monitor_orchestration "$project_dir" &
    
    echo -e "${GREEN}✅ Orchestration initialized with full Claude features${NC}"
}

# Continuous orchestration monitoring
monitor_orchestration() {
    local project_dir="$1"
    local memory_file="$project_dir/.taco/memory/claude_memory.json"
    local graph_file="$project_dir/.taco/dependency_graph.json"
    
    while true; do
        # Check agent statuses
        local total_agents=$(jq '.nodes | length' "$graph_file")
        local completed_agents=$(jq '[.nodes[] | select(.status == "completed")] | length' "$graph_file")
        
        # Update dashboard
        clear
        echo "═══════════════════════════════════════════════════════"
        echo "   TACO v2.0 ORCHESTRATION DASHBOARD"
        echo "═══════════════════════════════════════════════════════"
        echo ""
        echo "Progress: $completed_agents / $total_agents agents completed"
        echo ""
        echo "Dependency Graph:"
        jq -r '.execution_phases[] | "Phase \(.phase): \(.agents | join(", "))"' "$graph_file"
        echo ""
        echo "Recent Communications:"
        tail -n 5 "$project_dir/.orchestrator/communication.log"
        echo ""
        echo "Shared Memory Keys:"
        jq -r '.shared_knowledge | keys[]' "$memory_file" 2>/dev/null | head -5
        echo ""
        echo "Test Status:"
        tail -n 3 "$project_dir/.orchestrator/test_results.log"
        echo "═══════════════════════════════════════════════════════"
        
        # Check for completion
        if [ "$completed_agents" -eq "$total_agents" ]; then
            echo -e "${GREEN}🎉 All agents completed successfully!${NC}"
            break
        fi
        
        sleep 2
    done
}

# Export functions for use in other modules
export -f initialize_claude_memory
export -f build_dependency_graph
export -f launch_agents_with_dependencies
export -f enhanced_message_relay
export -f execute_orchestration_v2
export -f monitor_orchestration