#!/usr/bin/env bash
# TACO - Tmux Agent Command Orchestrator
# Agent Management and Specification

# Two-phase Mother initialization - Phase 1: Specification Only
create_specification_prompt() {
    local user_request="$1"
    
    cat << EOF
🚨 PHASE 1: SPECIFICATION GENERATION 🚨

You are the MOTHER ORCHESTRATOR in TACO. 
In this phase, you must ONLY output an AGENT_SPEC block to define agents.

DO NOT use any tools (TodoWrite, List, Read, Search, Task, Bash).
DO NOT explore files or start building.
JUST output the specification.

PREFERRED FORMAT: JSON (most reliable)
Return a STRICT JSON object between explicit markers so we can parse deterministically.
Do NOT include backticks or markdown fences in the JSON block.

AGENT_SPEC_JSON_START
{
  "agents": [
    {
      "window": 3,
      "name": "frontend_dev",
      "role": "Build React components and UI",
      "depends_on": [],
      "notifies": ["validator"],
      "wait_for": []
    },
    {
      "window": 4,
      "name": "backend_dev",
      "role": "Create API endpoints and database",
      "depends_on": [],
      "notifies": ["validator"],
      "wait_for": []
    }
  ]
}
AGENT_SPEC_JSON_END

If you cannot output JSON, fallback to the legacy block format below.

After you output the spec, you'll enter PHASE 2: COORDINATION MODE where you'll orchestrate all agents.

Now output an AGENT_SPEC block for:

PROJECT: $user_request

⚠️ CONSTRAINTS ⚠️
- NO tools allowed whatsoever
- NO file exploration  
- NO analysis or planning phase
- NO explanations or commentary
- JUST output the specification block

Example (CREATE YOUR OWN - DO NOT COPY):
<<EXAMPLE>>
AGENT_SPEC_START
AGENT:3:frontend_dev:Build React components and UI
DEPENDS_ON:none
NOTIFIES:validator
WAIT_FOR:none

AGENT:4:backend_dev:Create API endpoints and database
DEPENDS_ON:none
NOTIFIES:validator
WAIT_FOR:none

AGENT:5:validator:Validate code quality and standards
DEPENDS_ON:frontend_dev,backend_dev
NOTIFIES:tester
WAIT_FOR:none

AGENT:6:tester:Run tests and ensure quality
DEPENDS_ON:validator
NOTIFIES:none
WAIT_FOR:validator
AGENT_SPEC_END
<</EXAMPLE>>

YOUR RESPONSE MUST START WITH:
AGENT_SPEC_START

AND END WITH:
AGENT_SPEC_END

Rules:
- Windows start from 3 (0=Mother, 1=monitor, 2=test-monitor)
- Create real agent names (not "agent_name")
- MUST include validator agents for code quality
- MUST include testing/QA agents
- Include 5-15 agents based on project complexity

START YOUR RESPONSE NOW WITH THE AGENT_SPEC_START LINE:
EOF
}

# Two-phase Mother initialization - Phase 2: Coordination
create_coordination_prompt() {
    local testing_requirements="$1"
    local deployment_guidance="$2"  
    local connection_strategy="$3"
    local project_dir="$4"
    
    cat << EOF
=== ALL AGENTS CREATED AND READY ===

You are now in COORDINATION MODE. Your agents are ready for instructions.

CRITICAL: Use the Bash tool to execute ALL communication commands!

TO SEND MESSAGES TO AGENTS, YOU MUST USE 3 SEPARATE BASH TOOL CALLS:

🔥 STEP 1: Bash tool → tmux send-keys -t taco:WINDOW_NUMBER "Your message"
🔥 STEP 2: Bash tool → sleep 0.2  
🔥 STEP 3: Bash tool → tmux send-keys -t taco:WINDOW_NUMBER Enter

⚠️ EACH STEP MUST BE A SEPARATE BASH TOOL EXECUTION ⚠️

MANDATORY REQUIREMENTS:
- Testing Strategy: $testing_requirements
- Deployment: $deployment_guidance  
- Connections: $connection_strategy
- Test ALL endpoints with curl before marking complete
- ALL builds must succeed without errors
- ALL errors must be caught, logged, and fixed immediately

🔄 ORCHESTRATION REQUIREMENTS:
1. ENABLE COLLABORATION: Instruct agents to share specifications with each other
2. PREVENT OVERLAP: Ensure agents coordinate to avoid duplicate work
3. FACILITATE COMMUNICATION: Encourage agents to ask questions and share updates
4. MONITOR INTEGRATION: Watch for integration points between agents
5. ENFORCE SHARING: Remind agents to broadcast their designs and APIs

EXAMPLE - To send workspace to agent 3:

STEP 1: Bash tool with command:
tmux send-keys -t taco:3.0 "Your workspace is $project_dir/frontend. Start building the UI components."

STEP 2: Bash tool with command:
sleep 0.2

STEP 3: Bash tool with command:
tmux send-keys -t taco:3.0 Enter

BEGIN COORDINATING NOW! Use Bash tool to send workspace instructions to each agent.
EOF
}

# Enhanced mother prompt with testing and connection focus
create_mother_prompt() {
    local user_request="$1"
    
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
    
    # Use the two-phase approach: specification first, then coordination
    create_specification_prompt "$user_request"
}

# Function to strip ANSI color codes
strip_ansi_codes() {
    echo "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

# Parse agent specification with smart window reassignment (compatible with older bash)
parse_agent_specification() {
    local spec_file="$1"
    local output_file="${2:-}"
    local agent_specs=()
    local next_window=3  # Start from window 3 (0=mother, 1=monitor, 2=test-monitor)
    
    local current_agent_name=""
    local current_agent_role=""
    local current_original_window=""
    local current_memory_share=""
    local current_parallel_with=""
    local current_sub_agents=""
    local current_thinking_mode=""
    local current_memory_keys=""
    local collecting_role=false
    
    # Simple duplicate checking using space-separated strings
    local used_names=""
    local used_windows=""
    
    log "INFO" "PARSER" "Starting to parse agent specification from $spec_file"
    
    # Helper function to check if name is already used
    is_name_used() {
        local name="$1"
        [ -n "$used_names" ] && [[ " $used_names " == *" $name "* ]]
    }
    
    # Helper function to check if window is already used  
    is_window_used() {
        local window="$1"
        [ -n "$used_windows" ] && [[ " $used_windows " == *" $window "* ]]
    }
    
    # First, try to parse JSON spec if present (preferred)
    if command -v jq >/dev/null 2>&1; then
        local json_block
        json_block=$(awk 'BEGIN{capture=0} /AGENT_SPEC_JSON_START/{capture=1;next} /AGENT_SPEC_JSON_END/{capture=0} capture{print}' "$spec_file")
        if [ -n "$json_block" ]; then
            # Strip markdown fences/backticks and trim
            json_block=$(printf '%s' "$json_block" | sed -E 's/^```.*$//g; s/^`+$//g; s/`+$//g')
            # Drop obvious prompt prefixes that can leak into captures (e.g., cursh>, claude>, etc.)
            json_block=$(printf '%s' "$json_block" | sed -E 's/^[A-Za-z_][A-Za-z0-9_]*> *//')
            # Normalize and parse
            local count
            count=$(printf '%s' "$json_block" | jq -r '(.agents // .Agents // .AGENTS) | length' 2>/dev/null || echo "")
            if [ -n "$count" ] && [ "$count" != "null" ] && [ "$count" -ge 1 ] 2>/dev/null; then
                # Build agent_specs as window:name:role
                while IFS= read -r line; do
                    agent_specs+=("$line")
                done < <(printf '%s' "$json_block" | jq -r '(.agents // .Agents // .AGENTS)[] | "\(.window):\(.name):\(.role)"')
                # Write to output if requested
                if [ -n "$output_file" ]; then
                    : > "$output_file"
                    for spec in "${agent_specs[@]}"; do
                        echo "$spec" >> "$output_file"
                    done
                fi
                log "INFO" "PARSER" "Parsed ${#agent_specs[@]} agents from JSON specification"
                return 0
            else
                log "WARN" "PARSER" "JSON spec block present but not valid JSON agents array"
            fi
        fi
    fi

    # Otherwise, check if we have a valid legacy spec block
    local has_spec_start=false
    local has_spec_end=false
    
    while IFS= read -r line; do
        # Strip leading/trailing whitespace for checking markers
        local trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        if [[ "$trimmed_line" =~ AGENT_SPEC_START ]]; then
            has_spec_start=true
        elif [[ "$trimmed_line" =~ AGENT_SPEC_END ]]; then
            has_spec_end=true
        fi
    done < "$spec_file"
    
    if [ "$has_spec_start" = false ] || [ "$has_spec_end" = false ]; then
        log "ERROR" "PARSER" "No valid AGENT_SPEC block found in $spec_file"
        return 1
    fi
    
    while IFS= read -r line; do
        # Strip ANSI codes, simple bullets, and trim whitespace (BSD sed-safe)
        line=$(strip_ansi_codes "$line")
        line=$(echo "$line" | sed -E 's/^[>\*\-•[:space:]]+//; s/^[[:space:]]*//; s/[[:space:]]*$//')
        [ -z "$line" ] && continue
        
        # Normalize for case-insensitive matching
        local line_upper=$(echo "$line" | tr '[:lower:]' '[:upper:]')
        
        # Debug output
        # log "DEBUG" "PARSER" "Processing line: $line"
        
        if [[ "$line_upper" =~ ^AGENT[[:space:]]*:?[[:space:]]* ]]; then
            # Remove leading AGENT token (with optional colon) and capture rest
            local rest=$(echo "$line" | sed -E 's/^[Aa][Gg][Ee][Nn][Tt][[:space:]]*:?[[:space:]]*//')
            # Split on ':' – tolerate spaces around delimiters
            local matched_window=$(echo "$rest" | cut -d: -f1 | sed 's/[[:space:]]//g')
            local matched_name=$(echo "$rest" | cut -d: -f2 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
            local matched_role=$(echo "$rest" | cut -d: -f3- | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
            
            # Fallback: formats like "name - role" without window
            if [ -z "$matched_name" ] && echo "$rest" | grep -q " - "; then
                matched_window=""
                matched_name=$(echo "$rest" | sed -E 's/ *-.*$//')
                matched_role=$(echo "$rest" | sed -E 's/^.*- *//')
            fi
            
            # Remove any trailing :claude or other agent type indicators
            matched_role=$(echo "$matched_role" | sed 's/:claude[[:space:]]*$//' | sed 's/:openai[[:space:]]*$//' | sed 's/:gemini[[:space:]]*$//')
            
            # Skip placeholder agent entries (exact match for template)
            if [[ "$matched_name" == "agent_name" ]] && [[ "$matched_role" == "role description" ]]; then
                log "WARN" "PARSER" "Skipping template placeholder: agent_name"
                collecting_role=false
                continue
            fi
            
            # First, finalize any previous agent being collected
            if [ "$collecting_role" = true ]; then
                # Find next available window
                while is_window_used "$next_window" || [ $next_window -eq 0 ] || [ $next_window -eq 1 ] || [ $next_window -eq 2 ]; do
                    next_window=$((next_window + 1))
                    if [ $next_window -gt 50 ]; then
                        log "ERROR" "PARSER" "Exceeded maximum window limit"
                        break
                    fi
                done
                window_num=$next_window
                
                # Clean up role description
                current_agent_role=$(echo "$current_agent_role" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//')
                
                log "INFO" "PARSER" "Found agent: $current_agent_name (window $window_num, originally $current_original_window)"
                
                # Record usage with V2 fields if present
                used_windows="$used_windows $window_num"
                used_names="$used_names $current_agent_name"
                local spec_line="$window_num:$current_agent_name:$current_agent_role"
                if [ -n "$current_memory_share" ] || [ -n "$current_parallel_with" ] || [ -n "$current_sub_agents" ] || [ -n "$current_thinking_mode" ] || [ -n "$current_memory_keys" ]; then
                    spec_line="${spec_line}|MEMORY_SHARE:${current_memory_share}|PARALLEL_WITH:${current_parallel_with}|SUB_AGENTS:${current_sub_agents}|THINKING_MODE:${current_thinking_mode}|MEMORY_KEYS:${current_memory_keys}"
                fi
                agent_specs+=("$spec_line")
                
                next_window=$((next_window + 1))
            fi
            
            # Now start processing the new agent
            original_window="$matched_window"
            agent_name="$matched_name"
            current_agent_role="$matched_role"
            collecting_role=true
            
            # Check for duplicate agent names
            if is_name_used "$agent_name"; then
                log "WARN" "PARSER" "Duplicate agent name: $agent_name (skipping)"
                collecting_role=false
                continue
            fi
            
            # Validate agent name
            if [ -z "$agent_name" ] || [[ "$agent_name" =~ ^[[:space:]]*$ ]]; then
                log "WARN" "PARSER" "Invalid agent name (empty or whitespace only)"
                collecting_role=false
                continue
            fi
            
            # Store current agent info but don't finalize yet
            current_original_window="$original_window"
            current_agent_name="$agent_name"
            # Reset V2 fields for new agent
            current_memory_share=""
            current_parallel_with=""
            current_sub_agents=""
            current_thinking_mode=""
            current_memory_keys=""
            
        elif [[ "$line_upper" =~ ^MEMORY_SHARE: ]]; then
            current_memory_share="${BASH_REMATCH[1]}"
        elif [[ "$line_upper" =~ ^PARALLEL_WITH: ]]; then
            current_parallel_with="${BASH_REMATCH[1]}"
        elif [[ "$line_upper" =~ ^SUB_AGENTS: ]]; then
            current_sub_agents="${BASH_REMATCH[1]}"
        elif [[ "$line_upper" =~ ^THINKING_MODE: ]]; then
            current_thinking_mode="${BASH_REMATCH[1]}"
        elif [[ "$line_upper" =~ ^MEMORY_KEYS: ]]; then
            current_memory_keys="${BASH_REMATCH[1]}"
        elif [[ "$line_upper" =~ ^DEPENDS_ON: ]] || [[ "$line_upper" =~ ^NOTIFIES: ]] || [[ "$line_upper" =~ ^WAIT_FOR: ]] || \
              [[ "$line_upper" =~ ^AGENT_SPEC_END$ ]] || [[ "$line" =~ ^\[.*\]$ ]]; then
            # These lines are handled elsewhere or should be ignored
            :
        elif [ "$collecting_role" = true ]; then
            # Continue collecting role description lines
            current_agent_role="$current_agent_role $line"
        fi
    done < <(awk 'BEGIN{IGNORECASE=1} /AGENT_SPEC_START/,/AGENT_SPEC_END/' "$spec_file" | grep -iv 'AGENT_SPEC_START' | grep -iv 'AGENT_SPEC_END')
    
    # Process any remaining agent being collected
    if [ "$collecting_role" = true ]; then
        while is_window_used "$next_window" || [ $next_window -eq 0 ] || [ $next_window -eq 1 ] || [ $next_window -eq 2 ]; do
            next_window=$((next_window + 1))
            if [ $next_window -gt 50 ]; then
                log "ERROR" "PARSER" "Exceeded maximum window limit"
                break
            fi
        done
        window_num=$next_window
        
        current_agent_role=$(echo "$current_agent_role" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//')
        
        log "INFO" "PARSER" "Found agent: $current_agent_name (window $window_num, originally $current_original_window)"
        
        used_windows="$used_windows $window_num"
        used_names="$used_names $current_agent_name"
        # Include V2 fields if present
        local spec_line="$window_num:$current_agent_name:$current_agent_role"
        if [ -n "$current_memory_share" ] || [ -n "$current_parallel_with" ] || [ -n "$current_sub_agents" ] || [ -n "$current_thinking_mode" ] || [ -n "$current_memory_keys" ]; then
            spec_line="${spec_line}|MEMORY_SHARE:${current_memory_share}|PARALLEL_WITH:${current_parallel_with}|SUB_AGENTS:${current_sub_agents}|THINKING_MODE:${current_thinking_mode}|MEMORY_KEYS:${current_memory_keys}"
        fi
        agent_specs+=("$spec_line")
    fi
    
    # Return results
    log "INFO" "PARSER" "Parsed ${#agent_specs[@]} agents from specification"
    
    if [ -n "$output_file" ]; then
        # Write to file if provided
        printf '%s\n' "${agent_specs[@]}" > "$output_file"
    else
        # Echo to stdout
        for spec in "${agent_specs[@]}"; do
            echo "$spec"
        done
    fi
}

# Validate specification quality
validate_agent_specification() {
    local agent_specs=("$@")
    local min_agents=1
    local max_agents=20
    local agent_count=${#agent_specs[@]}
    
    if [ $agent_count -lt $min_agents ]; then
        log "ERROR" "VALIDATOR" "No agents found in specification"
        return 1
    fi
    
    if [ $agent_count -gt $max_agents ]; then
        log "WARN" "VALIDATOR" "Large number of agents ($agent_count). Performance may be impacted"
    fi
    
    # Check for essential agent types
    local has_tester=false
    local has_validator=false
    local has_devops=false
    for spec in "${agent_specs[@]}"; do
        IFS=':' read -r window_num agent_name agent_role <<< "$spec"
        if echo "$agent_role" | grep -qi "test\\|qa\\|quality"; then
            has_tester=true
        fi
        if echo "$agent_role" | grep -qi "validat\\|review\\|check\\|lint\\|audit"; then
            has_validator=true
        fi
        if echo "$agent_role" | grep -qi "devops\\|deploy\\|docker\\|infrastructure"; then
            has_devops=true
        fi
    done
    
    if [ "$has_validator" = false ]; then
        log "ERROR" "VALIDATOR" "No validator agent found. Validators are REQUIRED for code quality."
        return 1
    fi
    
    if [ "$has_tester" = false ]; then
        log "ERROR" "VALIDATOR" "No testing agent found. Testing agents are REQUIRED."
        return 1
    fi
    
    if [ "$has_devops" = false ]; then
        log "WARN" "VALIDATOR" "No dedicated DevOps/deployment agent found. This may impact deployment."
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
    local project_prompt="$7"
    local agent_specs=("${@:8}")
    
    local agent_prompt="You are an AI development agent in TACO (Tmux Agent Command Orchestrator).

PROJECT: $project_prompt
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

🔥 MANDATORY COMMUNICATION PROTOCOL FOR ALL AGENTS 🔥

TO SEND ANY MESSAGE TO ANY AGENT OR MOTHER, YOU MUST USE 3 SEPARATE BASH TOOL CALLS:

🔥 STEP 1: Use Bash tool to execute ONLY: tmux send-keys -t $SESSION_NAME:TARGET_WINDOW \"[AGENT-$window_num → TARGET]: Your message here\"
🔥 STEP 2: Use Bash tool to execute ONLY: sleep 0.2
🔥 STEP 3: Use Bash tool to execute ONLY: tmux send-keys -t $SESSION_NAME:TARGET_WINDOW Enter

⚠️  EACH STEP MUST BE A SEPARATE BASH TOOL EXECUTION
⚠️  DO NOT COMBINE ANY STEPS INTO ONE COMMAND
⚠️  NEVER use && or semicolon to chain commands
⚠️  Each Bash tool execution must contain EXACTLY ONE command

EXAMPLE - To notify Agent 3 that API is ready:
STEP 1: Bash tool → tmux send-keys -t $SESSION_NAME:3.0 \"[AGENT-$window_num → AGENT-3]: API endpoints ready at http://localhost:3001\"
STEP 2: Bash tool → sleep 0.2
STEP 3: Bash tool → tmux send-keys -t $SESSION_NAME:3.0 Enter

EXAMPLE - To report to Mother:
STEP 1: Bash tool → tmux send-keys -t $SESSION_NAME:0.0 \"[AGENT-$window_num → MOTHER]: Task completed successfully\"
STEP 2: Bash tool → sleep 0.2  
STEP 3: Bash tool → tmux send-keys -t $SESSION_NAME:0.0 Enter

IMPORTANT: Use window numbers from the agent directory above for accurate messaging."
    else
        agent_prompt+="
$agent_directory

🔥 MANDATORY COMMUNICATION PROTOCOL FOR ALL AGENTS 🔥

TO SEND ANY MESSAGE TO ANY AGENT OR MOTHER, YOU MUST USE 3 SEPARATE BASH TOOL CALLS:

🔥 STEP 1: Use Bash tool to execute ONLY: tmux send-keys -t $SESSION_NAME:TARGET_WINDOW \"[WINDOW-$window_num → TARGET]: Your message here\"
🔥 STEP 2: Use Bash tool to execute ONLY: sleep 0.2
🔥 STEP 3: Use Bash tool to execute ONLY: tmux send-keys -t $SESSION_NAME:TARGET_WINDOW Enter

⚠️  EACH STEP MUST BE A SEPARATE BASH TOOL EXECUTION
⚠️  DO NOT COMBINE ANY STEPS INTO ONE COMMAND
⚠️  NEVER use && or semicolon to chain commands
⚠️  Each Bash tool execution must contain EXACTLY ONE command

EXAMPLE - To notify Window 3 that API is ready:
STEP 1: Bash tool → tmux send-keys -t $SESSION_NAME:3.0 \"[WINDOW-$window_num → WINDOW-3]: API endpoints ready at http://localhost:3001\"
STEP 2: Bash tool → sleep 0.2
STEP 3: Bash tool → tmux send-keys -t $SESSION_NAME:3.0 Enter

EXAMPLE - To report to Mother:
STEP 1: Bash tool → tmux send-keys -t $SESSION_NAME:0.0 \"[WINDOW-$window_num → MOTHER]: Task completed successfully\"
STEP 2: Bash tool → sleep 0.2  
STEP 3: Bash tool → tmux send-keys -t $SESSION_NAME:0.0 Enter

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

🔄 CRITICAL COLLABORATION REQUIREMENTS:
1. SHARE SPECIFICATIONS: When you design an API, database schema, or interface:
   - WRITE your spec to: $PROJECT_DIR/.orchestrator/shared_specs/[agent_name]_spec.md
   - IMMEDIATELY notify relevant agents with the specification
   - Example: "[AGENT-$window_num → AGENT-4]: API spec ready at .orchestrator/shared_specs/backend_spec.md"
   
2. COORDINATE WORK: Before starting any task:
   - CHECK what other agents are working on to avoid duplication
   - ANNOUNCE what you're about to build
   - Example: "[AGENT-$window_num → ALL]: Starting work on user authentication module"

3. REQUEST INFORMATION: Don't guess - ASK other agents:
   - Need an API endpoint? Ask the backend agent
   - Need component props? Ask the frontend agent
   - Example: "[AGENT-$window_num → AGENT-3]: What props does the UserCard component accept?"

4. BROADCAST UPDATES: When you complete significant work:
   - Notify ALL relevant agents
   - Share what's now available for them to use
   - Example: "[AGENT-$window_num → ALL]: Database schema ready with users, posts, comments tables"

5. VALIDATION COORDINATION:
   - Before marking work complete, notify validator agent
   - Share test results with testing agent
   - Coordinate with dependent agents before major changes

Remember: You're part of a TEAM. No agent works in isolation. Communicate early and often!

Wait for Mother's initial instructions to begin.

=== END OF AGENT PROMPT ==="
    
    echo "$agent_prompt"
}
