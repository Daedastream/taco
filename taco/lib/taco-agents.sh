#!/usr/bin/env bash
# TACO - Tmux Agent Command Orchestrator
# Agent Management and Specification

# Enhanced mother prompt with testing and connection focus
create_mother_prompt() {
    local user_request="$1"
    local agent_count="$2"
    local count_instruction="$3"
    
    # Build testing requirements - now mandatory and comprehensive
    local testing_requirements="comprehensive testing including unit tests, integration tests, end-to-end tests, and API endpoint tests"
    
    # Build deployment guidance
    local deployment_guidance=""
    case $DEPLOYMENT_ENV in
        "local") deployment_guidance="Focus on local development setup" ;;
        "docker") deployment_guidance="Use Docker containers, avoid localhost, use container names" ;;
        "cloud") deployment_guidance="Prepare for cloud deployment, use environment variables" ;;
        "mixed") deployment_guidance="Support both local and containerized environments" ;;
    esac
    
    # Build connection strategy
    local connection_strategy=""
    case $CONNECTION_STRATEGY in
        "manual") connection_strategy="Agents must specify their ports manually" ;;
        "discovery") connection_strategy="Use service discovery for inter-service communication" ;;
        "automatic") connection_strategy="Automatically assign ports starting from 3000" ;;
    esac
    
    cat << EOF
You are the MOTHER orchestrator agent for TACO (Tmux Agent Command Orchestrator).

PROJECT REQUEST: $user_request
PROJECT ROOT: $PROJECT_DIR

CRITICAL REQUIREMENTS FOR THIS PROJECT:
1. ALL code must include: $testing_requirements
2. ALL connections between services must use a shared registry
3. ALL endpoints must be tested with curl before marking as complete
4. ALL builds must succeed without errors before proceeding
5. ALL errors must be caught, logged, and fixed immediately
6. $deployment_guidance
7. $connection_strategy

ANALYZE THE PROJECT REQUEST AND OUTPUT A SPECIFICATION.

You MUST output agent specifications in this EXACT format:

AGENT_SPEC_START
AGENT:3:frontend:React frontend developer - builds UI with tests
DEPENDS_ON:none
NOTIFIES:4,7,8
WAIT_FOR:none
AGENT:4:backend:Express API developer - creates REST endpoints with tests
DEPENDS_ON:5
NOTIFIES:3,6,7,8
WAIT_FOR:DB_READY
AGENT:5:database:Database architect - designs schemas with migrations
DEPENDS_ON:none
NOTIFIES:4
WAIT_FOR:none
AGENT:6:mobile:React Native developer - builds mobile app with tests
DEPENDS_ON:4
NOTIFIES:3,7,8
WAIT_FOR:API_READY
AGENT:7:tester:QA engineer - runs all tests and validates connections
DEPENDS_ON:none
NOTIFIES:0,3,4,5,6
WAIT_FOR:UI_READY,API_READY,MOBILE_READY
AGENT:8:devops:DevOps engineer - manages Docker, ports, and deployments
DEPENDS_ON:none
NOTIFIES:0,4,5
WAIT_FOR:none
AGENT_SPEC_END

CRITICAL SPECIFICATION RULES:
- Window 0 is you (Mother), window 1 is monitor, window 2 is test-monitor
- Start agents at window 3 and increment sequentially (3, 4, 5, 6, etc.)
- NEVER reuse window numbers - each agent gets a unique number
- NEVER create duplicate agent names - each must be unique and have distinct responsibilities
- Create 2-15 agents total (optimal range for parallel development)
- Include a dedicated testing agent and deployment/DevOps agent
- Each agent should handle a specific, well-defined domain of work
- Agents should be designed for maximum parallel development with minimal conflicts
- Design dependencies carefully - avoid circular dependencies
- Agent names should clearly reflect their unique function (e.g., 'webui', 'mobileapp', 'apiserver', 'userauth', 'database', 'testing', 'deployment')

AGENT DESIGN PRINCIPLES:
- Divide work by functional boundaries, not arbitrary splits
- Ensure each agent can work independently on their domain
- Use DEPENDS_ON and WAIT_FOR to coordinate between agents
- Design for parallel work - minimize bottlenecks

$count_instruction

CONNECTION REGISTRY:
After creating agents, you MUST establish a connection registry by having each agent register their services:

Example:
tmux send-keys -t taco:3.0 "echo '{\"services\": {\"api\": \"http://localhost:3001\"}, \"ports\": {\"api\": 3001}}' | jq -s '.[0] * .[1]' $PROJECT_DIR/.orchestrator/connections.json - > /tmp/conn.json && mv /tmp/conn.json $PROJECT_DIR/.orchestrator/connections.json"
tmux send-keys -t taco:3.0 Enter

Now analyze the project and OUTPUT YOUR SPECIFICATION.
EOF
}

# Parse agent specification with smart window reassignment
parse_agent_specification() {
    local spec_file="$1"
    local agent_specs=()
    local agent_deps=()
    local agent_notifies=()
    local agent_waits=()
    local -A used_windows
    local -A used_names
    local next_window=3  # Start from window 3 (0=mother, 1=monitor, 2=test-monitor)
    
    local current_agent_idx=-1
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [ -z "$line" ] && continue
        
        if [[ "$line" =~ ^AGENT:([0-9]+):([^:]+):(.+)$ ]]; then
            local original_window="${BASH_REMATCH[1]}"
            local agent_name="${BASH_REMATCH[2]}"
            local agent_role="${BASH_REMATCH[3]}"
            
            # Reject duplicate agent names - they indicate poor specification
            if [ -n "${used_names[$agent_name]}" ]; then
                echo -e "${RED}❌ DUPLICATE AGENT NAME: $agent_name${NC}"
                echo -e "${RED}   This indicates Mother created a poor specification.${NC}"
                echo -e "${RED}   Each agent should have a unique name and distinct role.${NC}"
                echo -e "${YELLOW}   Skipping duplicate agent. Mother should create better specifications.${NC}"
                log "ERROR" "PARSER" "Rejected duplicate agent name: $agent_name"
                continue
            fi
            
            # Assign next available window (skip 0=mother, 1=monitor, 2=test-monitor)
            while [ -n "${used_windows[$next_window]}" ] || [ $next_window -eq 0 ] || [ $next_window -eq 1 ] || [ $next_window -eq 2 ]; do
                next_window=$((next_window + 1))
                # Safety check to prevent infinite loop
                if [ $next_window -gt 50 ]; then
                    echo -e "${RED}❌ Too many agents - exceeded window limit${NC}"
                    log "ERROR" "PARSER" "Exceeded maximum window limit"
                    break
                fi
            done
            local window_num=$next_window
            
            echo -e "${GREEN}Found agent: Window $window_num - $agent_name (was $original_window)${NC}"
            log "INFO" "PARSER" "Found agent: $agent_name (window $window_num, originally $original_window)"
            
            used_windows[$window_num]="$agent_name"
            used_names[$agent_name]="$window_num"
            agent_specs+=("$window_num:$agent_name:$agent_role")
            current_agent_idx=$((${#agent_specs[@]} - 1))
            
            next_window=$((next_window + 1))
        elif [[ "$line" =~ ^DEPENDS_ON:(.+)$ ]] && [ $current_agent_idx -ge 0 ]; then
            agent_deps[$current_agent_idx]="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^NOTIFIES:(.+)$ ]] && [ $current_agent_idx -ge 0 ]; then
            agent_notifies[$current_agent_idx]="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^WAIT_FOR:(.+)$ ]] && [ $current_agent_idx -ge 0 ]; then
            agent_waits[$current_agent_idx]="${BASH_REMATCH[1]}"
        fi
    done < <(awk '/AGENT_SPEC_START/,/AGENT_SPEC_END/' "$spec_file")
    
    # Return results
    echo "${agent_specs[@]}"
}

# Validate specification quality
validate_agent_specification() {
    local agent_specs=("$@")
    local min_agents=2
    local max_agents=15
    local agent_count=${#agent_specs[@]}
    
    if [ $agent_count -lt $min_agents ]; then
        echo -e "${RED}❌ Too few agents ($agent_count). Need at least $min_agents for proper coordination.${NC}"
        echo -e "${YELLOW}   Mother should create more specialized agents for better parallel development.${NC}"
        return 1
    fi
    
    if [ $agent_count -gt $max_agents ]; then
        echo -e "${RED}❌ Too many agents ($agent_count). Maximum is $max_agents to avoid complexity.${NC}"
        echo -e "${YELLOW}   Mother should consolidate similar roles into fewer, well-defined agents.${NC}"
        return 1
    fi
    
    # Check for essential agent types
    local has_tester=false
    local has_devops=false
    for spec in "${agent_specs[@]}"; do
        IFS=':' read -r window_num agent_name agent_role <<< "$spec"
        if echo "$agent_role" | grep -qi "test\\|qa\\|quality"; then
            has_tester=true
        fi
        if echo "$agent_role" | grep -qi "devops\\|deploy\\|docker\\|infrastructure"; then
            has_devops=true
        fi
    done
    
    if [ "$has_tester" = false ]; then
        echo -e "${YELLOW}⚠️  Warning: No dedicated testing agent found. This may impact quality assurance.${NC}"
    fi
    
    if [ "$has_devops" = false ]; then
        echo -e "${YELLOW}⚠️  Warning: No dedicated DevOps/deployment agent found. This may impact deployment.${NC}"
    fi
    
    return 0
}

# Create agent prompt with testing focus
create_agent_prompt() {
    local window_num="$1"
    local agent_name="$2" 
    local agent_role="$3"
    local depends_on="$4"
    local notifies="$5"
    local wait_for="$6"
    local agent_specs=("${@:7}")
    
    local agent_prompt="You are an AI development agent in TACO (Tmux Agent Command Orchestrator).

PROJECT: $user_prompt
PROJECT ROOT: $PROJECT_DIR

YOUR ROLE: $agent_role
YOUR WINDOW NUMBER: $window_num
YOUR AGENT NAME: $agent_name

YOUR WORKSPACE:
Wait for Mother to tell you: \"Your workspace is $PROJECT_DIR/[your-area]\"
Create ALL your files only in your assigned workspace

MANDATORY REQUIREMENTS (NON-NEGOTIABLE):
1. ALL code must include comprehensive tests (unit, integration, e2e, API)
2. Register your service endpoints and ports in the connection registry:
   # Get your port allocation first:
   PORT=\$($PROJECT_DIR/.orchestrator/port_helper.sh allocate your-service)
   # Then register it (deployment-aware URL):
   URL=\$($PROJECT_DIR/.orchestrator/port_helper.sh docker-url your-service \$PORT)
   echo '{\"services\": {\"your-service\": \"'\$URL'\"}, \"ports\": {\"your-service\": '\$PORT'}}' | jq -s '.[0] * .[1]' $PROJECT_DIR/.orchestrator/connections.json - > /tmp/conn.json && mv /tmp/conn.json $PROJECT_DIR/.orchestrator/connections.json
3. Test ALL endpoints with curl before marking complete
4. Smart Docker networking: Use deployment-aware URLs (localhost for local, container names for Docker)
   - Local development: http://localhost:PORT
   - Docker environment: http://service-name:PORT
   - Use port_helper.sh docker-url to generate correct URLs automatically
5. Report ALL test failures immediately
6. ALL builds must succeed without errors
7. ALL errors must be caught, logged, and fixed immediately
8. NO code can be marked complete without passing all tests

YOUR COMMUNICATION PLAN:
- DEPENDENCIES: $depends_on
- YOU MUST NOTIFY: $notifies
- WAIT_FOR: $wait_for

COMMUNICATION PROTOCOL:"
    
    # Build agent directory for role-based messaging
    local agent_directory="\nACTIVE AGENTS:"
    for other_spec in "${agent_specs[@]}"; do
        IFS=':' read -r other_window other_name other_role <<< "$other_spec"
        agent_directory+="\n- Window $other_window: $other_name ($other_role)"
    done
    
    if [ "$DISPLAY_MODE" = "panes" ]; then
        agent_prompt+="
Note: Agents are running in PANE MODE.
- Mother is at taco:0.0
- Monitor is at taco:1.0  
- Agents are in window 2, different panes

$agent_directory

COMMUNICATION METHODS:
1. Report to Mother (RECOMMENDED):
$PROJECT_DIR/.orchestrator/message_relay.sh \"[AGENT-$window_num → MOTHER]: Test results - 5 passed, 0 failed\"

2. Message another agent by window number:
$PROJECT_DIR/.orchestrator/message_relay.sh \"[AGENT-$window_num → AGENT-3]: API endpoints ready at port 3001\" 3

3. Direct tmux method (fallback only):
tmux send-keys -t taco:0.0 \"[AGENT-$window_num → MOTHER]: Test results - 5 passed, 0 failed\"
tmux send-keys -t taco:0.0 Enter

IMPORTANT: Use window numbers from the agent directory above for accurate messaging."
    else
        agent_prompt+="
$agent_directory

COMMUNICATION METHODS:
1. Report to Mother (RECOMMENDED):
$PROJECT_DIR/.orchestrator/message_relay.sh \"[WINDOW-$window_num → MOTHER]: Test results - 5 passed, 0 failed\"

2. Message another agent by window number:
$PROJECT_DIR/.orchestrator/message_relay.sh \"[WINDOW-$window_num → WINDOW-3]: API endpoints ready at port 3001\" 3

3. Direct tmux method (fallback only):
tmux send-keys -t taco:3.0 \"[WINDOW-$window_num → WINDOW-3]: API endpoints ready at port 3001\"
tmux send-keys -t taco:3.0 Enter

IMPORTANT: Use window numbers from the agent directory above for accurate messaging."
    fi
    
    agent_prompt+="

TESTING COMMANDS:
- Run your tests: npm test, pytest, go test, etc.
- Test endpoints: curl -X GET http://localhost:PORT/endpoint
- Validate connections: $PROJECT_DIR/.orchestrator/validate_connections.sh

PORT MANAGEMENT:
- Get next available port: $PROJECT_DIR/.orchestrator/port_helper.sh next
- Allocate port for service: $PROJECT_DIR/.orchestrator/port_helper.sh allocate service-name [preferred-port]
- Show all ports: $PROJECT_DIR/.orchestrator/port_helper.sh show
- Generate Docker URL: $PROJECT_DIR/.orchestrator/port_helper.sh docker-url service-name port

CONNECTION REGISTRY SHARING:
- ALWAYS check existing ports before allocating new ones
- ALWAYS update the registry when you start a service
- ALWAYS notify other agents when ports change
- Use the registry to discover other services: jq -r '.services | to_entries[] | \"\\(.key): \\(.value)\"' $PROJECT_DIR/.orchestrator/connections.json

Wait for Mother's initial instructions to begin."
    
    echo "$agent_prompt"
}