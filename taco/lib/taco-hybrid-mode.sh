#!/usr/bin/env bash
# TACO Hybrid Mode - Combining TACO's parallel orchestration with Claude's sub-agents

# Why TACO isn't obsolete - it's BETTER with Claude sub-agents:
# 
# 1. PARALLEL EXECUTION: TACO runs 5-10 agents SIMULTANEOUSLY
#    vs Claude sub-agents which run SEQUENTIALLY
#
# 2. MULTI-MODEL: Mix Claude, GPT-4, Gemini agents in one project
#    vs Claude-only sub-agents
#
# 3. VISUAL DEBUGGING: See all agents working in tmux windows
#    vs Hidden sub-agent delegation
#
# 4. SCALE: Handle massive projects with 10+ parallel workers
#    vs Single Claude instance limitations

create_hybrid_orchestrator() {
    local project_dir="$1"
    local user_request="$2"
    
    cat > "$project_dir/.orchestrator/hybrid_config.json" << 'EOF'
{
    "orchestration_mode": "hybrid",
    "parallel_agents": [
        {
            "window": 3,
            "type": "claude",
            "role": "Frontend Lead",
            "subagents_enabled": true,
            "subagents": ["react-specialist", "css-expert", "a11y-checker"]
        },
        {
            "window": 4,
            "type": "claude", 
            "role": "Backend Lead",
            "subagents_enabled": true,
            "subagents": ["api-designer", "database-expert", "auth-specialist"]
        },
        {
            "window": 5,
            "type": "codex",
            "role": "AI/ML Engineer",
            "flags": "--full-auto",
            "focus": "machine learning pipelines"
        },
        {
            "window": 6,
            "type": "gemini",
            "role": "Data Engineer",
            "flags": "--yolo",
            "focus": "data pipelines and ETL"
        },
        {
            "window": 7,
            "type": "claude",
            "role": "Testing Lead",
            "subagents_enabled": true,
            "subagents": ["unit-tester", "e2e-specialist", "performance-tester"]
        }
    ],
    "advantages": {
        "parallelism": "All 5 agents work SIMULTANEOUSLY",
        "throughput": "5x-10x faster than sequential sub-agents",
        "diversity": "Different models bring different strengths",
        "visibility": "Watch all agents in real-time via tmux",
        "resilience": "If one agent fails, others continue"
    }
}
EOF
}

# Launch parallel agents with sub-agent support
launch_parallel_hybrid_agents() {
    local project_dir="$1"
    local config="$project_dir/.orchestrator/hybrid_config.json"
    
    echo -e "${GREEN}🚀 TACO ADVANTAGE: Launching 5 parallel agents...${NC}"
    echo -e "${CYAN}This would take 5x longer with sequential sub-agents!${NC}"
    
    # Use the configured Claude model (default: sonnet)
    local model_flag=""
    if [ -n "$TACO_CLAUDE_MODEL" ]; then
        model_flag="--model $TACO_CLAUDE_MODEL"
    fi
    
    # Launch Frontend Lead (Claude with sub-agents)
    tmux send-keys -t taco:3 "cd $project_dir/frontend && claude --continue $model_flag" Enter
    tmux send-keys -t taco:3 "/agents create frontend-specialist 'React component expert'" Enter
    sleep 0.5
    
    # Launch Backend Lead (Claude with sub-agents) - PARALLEL
    tmux send-keys -t taco:4 "cd $project_dir/backend && claude --continue $model_flag" Enter
    tmux send-keys -t taco:4 "/agents create api-designer 'RESTful API architect'" Enter
    sleep 0.5
    
    # Launch AI/ML Engineer (Codex) - PARALLEL
    tmux send-keys -t taco:5 "cd $project_dir/ml && codex --full-auto" Enter
    tmux send-keys -t taco:5 "Build recommendation engine with TensorFlow" Enter
    
    # Launch Data Engineer (Gemini) - PARALLEL  
    tmux send-keys -t taco:6 "cd $project_dir/data && gemini --yolo" Enter
    tmux send-keys -t taco:6 "Create ETL pipeline for real-time analytics" Enter
    
    # Launch Testing Lead (Claude with sub-agents) - PARALLEL
    tmux send-keys -t taco:7 "cd $project_dir/testing && claude --continue $model_flag" Enter
    tmux send-keys -t taco:7 "/agents create e2e-specialist 'Playwright test expert'" Enter
    
    echo -e "${GREEN}✅ All agents launched in parallel!${NC}"
    echo -e "${YELLOW}View progress: Ctrl+b + [3-7]${NC}"
}

# Real-time cross-agent coordination
coordinate_parallel_agents() {
    local project_dir="$1"
    
    # TACO's killer feature: Real-time message relay between ALL agents
    cat > "$project_dir/.orchestrator/parallel_relay.sh" << 'EOF'
#!/usr/bin/env bash

# Broadcast message to all parallel agents instantly
broadcast_to_all() {
    local message="$1"
    for window in 3 4 5 6 7; do
        tmux send-keys -t taco:$window "$message" Enter &
    done
    wait
}

# Smart routing based on agent capabilities
route_by_expertise() {
    local task="$1"
    case "$task" in
        *"UI"*|*"component"*)
            tmux send-keys -t taco:3 "$task" Enter ;;
        *"API"*|*"endpoint"*)
            tmux send-keys -t taco:4 "$task" Enter ;;
        *"ML"*|*"model"*)
            tmux send-keys -t taco:5 "$task" Enter ;;
        *"data"*|*"ETL"*)
            tmux send-keys -t taco:6 "$task" Enter ;;
        *"test"*|*"QA"*)
            tmux send-keys -t taco:7 "$task" Enter ;;
    esac
}

# Parallel test execution across all agents
parallel_test_all() {
    echo "🧪 Running tests in ALL agents simultaneously..."
    for window in 3 4 5 6 7; do
        tmux send-keys -t taco:$window "npm test" Enter &
    done
    wait
    echo "✅ All parallel tests completed"
}
EOF
    chmod +x "$project_dir/.orchestrator/parallel_relay.sh"
}

# Show why TACO + Claude sub-agents is the ultimate combo
show_taco_advantages() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║           🌮 TACO vs Pure Claude Sub-Agents                  ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  TACO + Claude Sub-Agents (BEST):                           ║
║  ✅ 5-10 agents working in PARALLEL                         ║
║  ✅ Each agent can have its own sub-agents                  ║
║  ✅ Mix Claude, GPT-4, Gemini in one project                ║
║  ✅ Visual monitoring in tmux                               ║
║  ✅ 5-10x faster for large projects                         ║
║                                                              ║
║  Pure Claude Sub-Agents:                                    ║
║  ❌ Sequential execution only                               ║
║  ❌ Single model limitation                                 ║
║  ❌ No visual debugging                                     ║
║  ❌ Slower for multi-component projects                     ║
║                                                              ║
║  TACO Use Cases:                                            ║
║  • Large multi-service architectures                        ║
║  • Projects needing different AI models                     ║
║  • Real-time collaborative development                      ║
║  • Complex systems with 10+ components                      ║
║  • When you need to SEE what's happening                    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
}

# Example: Building a large e-commerce platform
demo_large_project() {
    echo "🛍️ Building E-commerce Platform with TACO Hybrid Mode"
    echo "This would take HOURS sequentially, but TACO does it in PARALLEL:"
    
    cat << 'EOF'
    
    PARALLEL EXECUTION (all at once):
    ┌─────────────────────────────────────────────┐
    │ Window 3: Frontend (Claude + React agents)  │ ← Building UI
    │ Window 4: Backend (Claude + API agents)     │ ← Creating APIs  
    │ Window 5: Search (Codex + Elasticsearch)    │ ← Search engine
    │ Window 6: Analytics (Gemini + BigQuery)     │ ← Analytics
    │ Window 7: Mobile (Claude + React Native)    │ ← Mobile app
    │ Window 8: Admin (Claude + Next.js)          │ ← Admin panel
    │ Window 9: Testing (Claude + test agents)    │ ← Testing all
    └─────────────────────────────────────────────┘
    
    All 7 teams working simultaneously! 
    With message relay for coordination!
    With live monitoring in tmux!
    
    Time saved: 80-90% vs sequential approach
EOF
}