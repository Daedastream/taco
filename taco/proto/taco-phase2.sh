#!/opt/homebrew/bin/bash

# TACO - Two-Phase Communication Fix
# This implements the separated specification and coordination phases

# Phase 1: Pure specification prompt with maximum constraints
create_specification_prompt() {
    local user_request="$1"
    local count_instruction="$2"
    
    cat << 'EOF'
🚨 SPECIFICATION GENERATION MODE 🚨

You are Claude in TACO specification mode. You have ONE job: output an AGENT_SPEC block.

❌ ABSOLUTELY NO TOOLS ❌
❌ NO TodoWrite, List, Read, Search, Task, Bash ❌
❌ NO file exploration ❌
❌ NO analysis, planning, or explanation ❌
❌ JUST output the specification block ❌

PROJECT: $user_request

$count_instruction

⚠️ CONSTRAINTS ⚠️
- NO tools allowed
- NO file exploration  
- NO analysis or planning
- NO explanations or commentary
- JUST output the specification block

Format (adapt for your project):

AGENT_SPEC_START
AGENT:3:agent_name:role description
DEPENDS_ON:none
NOTIFIES:testing_window
WAIT_FOR:none
[more agents...]
AGENT_SPEC_END

Rules:
- Windows 3,4,5,6,etc (0=Mother, 1=monitor, 2=test-monitor)
- Include testing + deployment agents
- 3-8 total agents
- Unique names and roles

🚨 OUTPUT ONLY THE SPEC BLOCK - NO TOOLS, NO ANALYSIS 🚨
EOF
}

# Phase 2: Communication prompt after agents are created
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

# Function to implement the two-phase approach
run_two_phase_mother() {
    local user_request="$1"
    local agent_count="$2" 
    local count_instruction="$3"
    local project_dir="$4"
    local session_name="$5"
    
    echo "🔄 Implementing two-phase Mother initialization..."
    
    # PHASE 1: Get specification only
    echo "📝 Phase 1: Getting agent specification..."
    
    local spec_prompt_file="$project_dir/.orchestrator/spec_prompt.txt"
    create_specification_prompt "$user_request" "$count_instruction" > "$spec_prompt_file"
    
    # Clear Mother's input and send specification prompt
    tmux send-keys -t "$session_name:0.0" C-u
    sleep 0.5
    
    while IFS= read -r line; do
        printf '%s\n' "$line" | tmux load-buffer -
        tmux paste-buffer -t "$session_name:0.0"
        tmux send-keys -t "$session_name:0.0" Enter
    done < "$spec_prompt_file"
    
    sleep 0.5
    tmux send-keys -t "$session_name:0.0" Enter
    
    echo "⏳ Waiting for specification (phase 1)..."
    sleep 15
    
    # Check for specification
    local capture=$(tmux capture-pane -t "$session_name:0.0" -p -S -3000)
    local clean_capture=$(echo "$capture" | sed 's/\x1b\[[0-9;]*m//g')
    
    echo "$clean_capture" > "$project_dir/.orchestrator/phase1_output.txt"
    
    if ! echo "$clean_capture" | grep -q "AGENT_SPEC_START"; then
        echo "❌ Phase 1 failed - no specification found"
        return 1
    fi
    
    echo "✅ Phase 1 complete - specification received"
    
    # PHASE 2: Send coordination instructions
    echo "🎯 Phase 2: Sending coordination instructions..."
    
    sleep 2
    
    # Build coordination prompt
    local testing_requirements="comprehensive testing including unit tests, integration tests, end-to-end tests, and API endpoint tests"
    local deployment_guidance="Focus on local development setup"
    local connection_strategy="Automatically assign ports starting from 3000"
    
    local coord_prompt_file="$project_dir/.orchestrator/coord_prompt.txt"
    create_coordination_prompt "$testing_requirements" "$deployment_guidance" "$connection_strategy" "$project_dir" > "$coord_prompt_file"
    
    # Send coordination prompt
    printf '%s' "$(cat "$coord_prompt_file")" | tmux load-buffer -
    tmux paste-buffer -t "$session_name:0.0"
    
    sleep 0.5
    tmux send-keys -t "$session_name:0.0" Enter
    
    echo "✅ Phase 2 complete - coordination instructions sent"
    
    return 0
}

echo "TACO Two-Phase Communication Fix loaded"