#!/usr/bin/env bash
# TACO Multi-Agent Support - Support for various AI agent types

# Launch agent based on type
launch_agent() {
    local agent_type="$1"
    local window_num="$2"
    local workspace="$3"
    local prompt="$4"
    local flags="${5:-}"
    
    case $agent_type in
        "claude")
            launch_claude_agent "$window_num" "$workspace" "$prompt" "$flags"
            ;;
        "openai")
            launch_openai_agent "$window_num" "$workspace" "$prompt" "$flags"
            ;;
        "anthropic_api")
            launch_anthropic_api_agent "$window_num" "$workspace" "$prompt" "$flags"
            ;;
        "gemini")
            launch_gemini_agent "$window_num" "$workspace" "$prompt" "$flags"
            ;;
        "codex")
            launch_codex_agent "$window_num" "$workspace" "$prompt" "$flags"
            ;;
        "llama")
            launch_llama_agent "$window_num" "$workspace" "$prompt" "$flags"
            ;;
        "mistral")
            launch_mistral_agent "$window_num" "$workspace" "$prompt" "$flags"
            ;;
        "grok")
            launch_grok_agent "$window_num" "$workspace" "$prompt" "$flags"
            ;;
        "perplexity")
            launch_perplexity_agent "$window_num" "$workspace" "$prompt" "$flags"
            ;;
        "custom")
            launch_custom_agent "$window_num" "$workspace" "$prompt" "$flags"
            ;;
        *)
            echo -e "${RED}Unknown agent type: $agent_type${NC}"
            return 1
            ;;
    esac
}

# Claude agent with sub-agents support
launch_claude_agent() {
    local window_num="$1"
    local workspace="$2"
    local prompt="$3"
    local flags="$4"
    
    echo -e "${CYAN}Launching Claude agent in window $window_num${NC}"
    
    # Check if sub-agents should be enabled
    if [ "$TACO_SUB_AGENTS_ENABLED" = "true" ]; then
        # Create sub-agent configurations
        create_claude_subagent_configs "$workspace"
        
        # Launch with MCP if enabled
        # Use the configured Claude model (default: sonnet)
        local model_flag=""
        if [ -n "$TACO_CLAUDE_MODEL" ]; then
            model_flag="--model $TACO_CLAUDE_MODEL"
        fi
        
        if [ "$TACO_MCP_ENABLED" = "true" ]; then
            tmux send-keys -t "taco:$window_num" "cd '$workspace' && claude --mcp-filesystem --mcp-git --continue $model_flag $flags" Enter
        else
            tmux send-keys -t "taco:$window_num" "cd '$workspace' && claude --continue $model_flag $flags" Enter
        fi
        
        sleep 0.5
        
        # Send initial prompt with thinking mode
        local thinking_mode="${THINKING_MODE:-}"
        if [ -n "$thinking_mode" ]; then
            tmux send-keys -t "taco:$window_num" "$thinking_mode and $prompt" Enter
        else
            tmux send-keys -t "taco:$window_num" "$prompt" Enter
        fi
        
        # Auto-create sub-agents
        sleep 1
        tmux send-keys -t "taco:$window_num" "/agents create code-reviewer 'Expert code review specialist'" Enter
        sleep 0.5
        tmux send-keys -t "taco:$window_num" "/agents create test-runner 'Comprehensive testing specialist'" Enter
    else
        # Classic Claude mode
        # Use the configured Claude model (default: sonnet)
        local model_flag=""
        if [ -n "$TACO_CLAUDE_MODEL" ]; then
            model_flag="--model $TACO_CLAUDE_MODEL"
        fi
        tmux send-keys -t "taco:$window_num" "cd '$workspace' && claude $model_flag $flags" Enter
        sleep 0.5
        tmux send-keys -t "taco:$window_num" "$prompt" Enter
    fi
}

# OpenAI GPT-4 agent
launch_openai_agent() {
    local window_num="$1"
    local workspace="$2"
    local prompt="$3"
    local flags="$4"
    
    echo -e "${CYAN}Launching OpenAI GPT-4 agent in window $window_num${NC}"
    
    # Check for API key
    if [ -z "$OPENAI_API_KEY" ]; then
        echo -e "${RED}❌ OPENAI_API_KEY not set${NC}"
        return 1
    fi
    
    # Create OpenAI wrapper script if needed
    create_openai_wrapper "$workspace"
    
    tmux send-keys -t "taco:$window_num" "cd '$workspace' && ./.taco/openai-agent.sh" Enter
    sleep 0.5
    tmux send-keys -t "taco:$window_num" "$prompt" Enter
}

# Create OpenAI wrapper script
create_openai_wrapper() {
    local workspace="$1"
    mkdir -p "$workspace/.taco"
    
    cat > "$workspace/.taco/openai-agent.sh" << 'EOF'
#!/usr/bin/env bash
# OpenAI GPT-4 Agent Wrapper

API_KEY="${OPENAI_API_KEY}"
MODEL="${OPENAI_MODEL:-gpt-4-turbo}"
TEMPERATURE="${OPENAI_TEMPERATURE:-0.7}"
MAX_TOKENS="${OPENAI_MAX_TOKENS:-4096}"

# Function to call OpenAI API
call_openai() {
    local prompt="$1"
    
    curl -s https://api.openai.com/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d "{
            \"model\": \"$MODEL\",
            \"messages\": [{\"role\": \"system\", \"content\": \"You are a helpful coding assistant working on a software project.\"}, {\"role\": \"user\", \"content\": \"$prompt\"}],
            \"temperature\": $TEMPERATURE,
            \"max_tokens\": $MAX_TOKENS,
            \"stream\": true
        }" | while read -r line; do
            echo "$line" | grep -o '"content":"[^"]*"' | sed 's/"content":"//;s/"$//' | sed 's/\\n/\n/g'
        done
}

# Interactive loop
echo "OpenAI GPT-4 Agent Ready"
echo "========================"

while true; do
    read -r -p "> " user_input
    if [ "$user_input" = "exit" ]; then
        break
    fi
    call_openai "$user_input"
done
EOF
    chmod +x "$workspace/.taco/openai-agent.sh"
}

# Anthropic API agent
launch_anthropic_api_agent() {
    local window_num="$1"
    local workspace="$2"
    local prompt="$3"
    local flags="$4"
    
    echo -e "${CYAN}Launching Anthropic API agent in window $window_num${NC}"
    
    if [ -z "$ANTHROPIC_API_KEY" ]; then
        echo -e "${RED}❌ ANTHROPIC_API_KEY not set${NC}"
        return 1
    fi
    
    create_anthropic_wrapper "$workspace"
    
    tmux send-keys -t "taco:$window_num" "cd '$workspace' && python3 ./.taco/anthropic-agent.py" Enter
    sleep 0.5
    tmux send-keys -t "taco:$window_num" "$prompt" Enter
}

# Create Anthropic API wrapper
create_anthropic_wrapper() {
    local workspace="$1"
    mkdir -p "$workspace/.taco"
    
    cat > "$workspace/.taco/anthropic-agent.py" << 'EOF'
#!/usr/bin/env python3
import os
import anthropic
import sys

client = anthropic.Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY"))

def get_completion(prompt):
    response = client.messages.create(
        model="claude-3-opus-20240229",
        max_tokens=4096,
        temperature=0.7,
        system="You are a helpful coding assistant working on a software project.",
        messages=[{"role": "user", "content": prompt}]
    )
    return response.content[0].text

print("Anthropic API Agent Ready")
print("========================")

while True:
    try:
        user_input = input("> ")
        if user_input.lower() == "exit":
            break
        response = get_completion(user_input)
        print(response)
    except KeyboardInterrupt:
        break
    except Exception as e:
        print(f"Error: {e}")
EOF
    chmod +x "$workspace/.taco/anthropic-agent.py"
}

# Local Llama agent (via Ollama)
launch_llama_agent() {
    local window_num="$1"
    local workspace="$2"
    local prompt="$3"
    local flags="$4"
    
    echo -e "${CYAN}Launching Llama agent in window $window_num${NC}"
    
    # Check if ollama is installed
    if ! command -v ollama > /dev/null; then
        echo -e "${RED}❌ Ollama not installed${NC}"
        echo "Install with: curl https://ollama.ai/install.sh | sh"
        return 1
    fi
    
    # Pull model if needed
    tmux send-keys -t "taco:$window_num" "ollama pull llama3:70b" Enter
    sleep 2
    
    # Launch interactive session
    tmux send-keys -t "taco:$window_num" "cd '$workspace' && ollama run llama3:70b" Enter
    sleep 1
    tmux send-keys -t "taco:$window_num" "$prompt" Enter
}

# Gemini agent
launch_gemini_agent() {
    local window_num="$1"
    local workspace="$2"
    local prompt="$3"
    local flags="$4"
    
    echo -e "${CYAN}Launching Gemini agent in window $window_num${NC}"
    
    if [ -z "$GEMINI_API_KEY" ]; then
        echo -e "${RED}❌ GEMINI_API_KEY not set${NC}"
        return 1
    fi
    
    # Check for gemini CLI or use API wrapper
    if command -v gemini > /dev/null; then
        tmux send-keys -t "taco:$window_num" "cd '$workspace' && gemini $flags" Enter
        sleep 0.5
        tmux send-keys -t "taco:$window_num" "$prompt" Enter
    else
        create_gemini_wrapper "$workspace"
        tmux send-keys -t "taco:$window_num" "cd '$workspace' && ./.taco/gemini-agent.sh" Enter
        sleep 0.5
        tmux send-keys -t "taco:$window_num" "$prompt" Enter
    fi
}

# Mistral agent
launch_mistral_agent() {
    local window_num="$1"
    local workspace="$2"
    local prompt="$3"
    local flags="$4"
    
    echo -e "${CYAN}Launching Mistral agent in window $window_num${NC}"
    
    if [ -z "$MISTRAL_API_KEY" ]; then
        echo -e "${RED}❌ MISTRAL_API_KEY not set${NC}"
        return 1
    fi
    
    create_mistral_wrapper "$workspace"
    tmux send-keys -t "taco:$window_num" "cd '$workspace' && python3 ./.taco/mistral-agent.py" Enter
    sleep 0.5
    tmux send-keys -t "taco:$window_num" "$prompt" Enter
}

# Grok agent (X.AI)
launch_grok_agent() {
    local window_num="$1"
    local workspace="$2"
    local prompt="$3"
    local flags="$4"
    
    echo -e "${CYAN}Launching Grok agent in window $window_num${NC}"
    
    if [ -z "$GROK_API_KEY" ]; then
        echo -e "${RED}❌ GROK_API_KEY not set${NC}"
        return 1
    fi
    
    create_grok_wrapper "$workspace"
    tmux send-keys -t "taco:$window_num" "cd '$workspace' && ./.taco/grok-agent.sh" Enter
    sleep 0.5
    tmux send-keys -t "taco:$window_num" "$prompt" Enter
}

# Perplexity agent
launch_perplexity_agent() {
    local window_num="$1"
    local workspace="$2"
    local prompt="$3"
    local flags="$4"
    
    echo -e "${CYAN}Launching Perplexity agent in window $window_num${NC}"
    
    if [ -z "$PERPLEXITY_API_KEY" ]; then
        echo -e "${RED}❌ PERPLEXITY_API_KEY not set${NC}"
        return 1
    fi
    
    create_perplexity_wrapper "$workspace"
    tmux send-keys -t "taco:$window_num" "cd '$workspace' && ./.taco/perplexity-agent.sh" Enter
    sleep 0.5
    tmux send-keys -t "taco:$window_num" "$prompt" Enter
}

# Custom agent support
launch_custom_agent() {
    local window_num="$1"
    local workspace="$2"
    local prompt="$3"
    local config="${CUSTOM_CONFIG:-$workspace/.taco/custom-agent.json}"
    
    echo -e "${CYAN}Launching custom agent in window $window_num${NC}"
    
    if [ ! -f "$config" ]; then
        echo -e "${RED}❌ Custom agent config not found: $config${NC}"
        return 1
    fi
    
    # Parse custom agent config
    local executable=$(jq -r '.executable' "$config")
    local args=$(jq -r '.args // ""' "$config")
    local env_vars=$(jq -r '.env_vars // {}' "$config")
    
    # Set environment variables
    for key in $(echo "$env_vars" | jq -r 'keys[]'); do
        local value=$(echo "$env_vars" | jq -r ".$key")
        export "$key=$value"
    done
    
    # Launch custom agent
    tmux send-keys -t "taco:$window_num" "cd '$workspace' && $executable $args" Enter
    sleep 0.5
    tmux send-keys -t "taco:$window_num" "$prompt" Enter
}

# Agent capability detection
detect_agent_capabilities() {
    local agent_type="$1"
    
    case $agent_type in
        "claude")
            echo "sub-agents mcp hooks thinking-modes headless cache"
            ;;
        "openai")
            echo "function-calling vision code-interpreter"
            ;;
        "gemini")
            echo "multimodal long-context grounding"
            ;;
        "llama")
            echo "local offline gpu-acceleration"
            ;;
        "mistral")
            echo "function-calling json-mode"
            ;;
        *)
            echo "basic"
            ;;
    esac
}

# Select best agent for task
select_best_agent_for_task() {
    local task="$1"
    
    # Analyze task requirements
    if echo "$task" | grep -iE "complex|architecture|design" > /dev/null; then
        echo "claude"  # Best for complex reasoning
    elif echo "$task" | grep -iE "image|vision|screenshot" > /dev/null; then
        echo "gemini"  # Best for multimodal
    elif echo "$task" | grep -iE "local|private|offline" > /dev/null; then
        echo "llama"   # Best for local/private
    elif echo "$task" | grep -iE "fast|quick|simple" > /dev/null; then
        echo "mistral" # Fast and efficient
    elif echo "$task" | grep -iE "search|research|latest" > /dev/null; then
        echo "perplexity" # Best for web search
    else
        echo "${TACO_DEFAULT_AGENT:-claude}"
    fi
}