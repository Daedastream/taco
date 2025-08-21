#!/usr/bin/env bash
# TACO Claude Code Sub-Agents Integration
# Leverages Claude Code's /agents feature for specialized task delegation

# Create project-specific sub-agents for TACO
create_taco_subagents() {
    local project_dir="$1"
    local project_type="$2"
    
    # Create .claude/subagents directory
    mkdir -p "$project_dir/.claude/subagents"
    
    # Generate sub-agent configurations based on project needs
    case $project_type in
        "web-app")
            create_frontend_agent "$project_dir"
            create_backend_agent "$project_dir"
            create_database_agent "$project_dir"
            create_test_runner_agent "$project_dir"
            create_devops_agent "$project_dir"
            ;;
        "mobile-app")
            create_mobile_agent "$project_dir"
            create_api_agent "$project_dir"
            create_test_runner_agent "$project_dir"
            ;;
        *)
            create_generic_agents "$project_dir"
            ;;
    esac
    
    # Create orchestrator configuration
    create_orchestrator_config "$project_dir"
}

# Frontend specialist sub-agent
create_frontend_agent() {
    local project_dir="$1"
    cat > "$project_dir/.claude/subagents/frontend-specialist.json" << 'EOF'
{
    "name": "frontend-specialist",
    "description": "Expert in React, Vue, Angular, and modern frontend development. Handles UI/UX implementation, state management, and component architecture.",
    "tools": ["Read", "Write", "Edit", "MultiEdit", "Bash", "WebFetch"],
    "system_prompt": "You are a frontend development specialist. Focus on:\n- Component architecture and reusability\n- Performance optimization (lazy loading, memoization)\n- Responsive design and accessibility\n- State management patterns\n- Testing with React Testing Library/Jest\n\nAlways validate your implementations with the test-runner subagent.\nCoordinate with backend-specialist for API integration.",
    "proactive": true
}
EOF
}

# Backend specialist sub-agent
create_backend_agent() {
    local project_dir="$1"
    cat > "$project_dir/.claude/subagents/backend-specialist.json" << 'EOF'
{
    "name": "backend-specialist",
    "description": "Expert in Node.js, Python, Go backend development. Handles API design, authentication, and server architecture.",
    "tools": ["Read", "Write", "Edit", "MultiEdit", "Bash", "Grep", "Glob"],
    "system_prompt": "You are a backend development specialist. Focus on:\n- RESTful and GraphQL API design\n- Authentication and authorization\n- Database integration and ORM usage\n- Performance and security best practices\n- API testing with Postman/curl\n\nRegister all endpoints in .orchestrator/connections.json.\nTest all endpoints before marking complete.",
    "proactive": true
}
EOF
}

# Database architect sub-agent
create_database_agent() {
    local project_dir="$1"
    cat > "$project_dir/.claude/subagents/database-architect.json" << 'EOF'
{
    "name": "database-architect",
    "description": "Database design expert for PostgreSQL, MongoDB, Redis. Handles schema design, migrations, and query optimization.",
    "tools": ["Read", "Write", "Edit", "Bash"],
    "system_prompt": "You are a database architecture specialist. Focus on:\n- Schema design and normalization\n- Index optimization\n- Migration scripts\n- Query performance tuning\n- Data integrity constraints\n\nCoordinate with backend-specialist for ORM mappings.\nDocument all schema changes in migrations/",
    "proactive": true
}
EOF
}

# Test runner sub-agent
create_test_runner_agent() {
    local project_dir="$1"
    cat > "$project_dir/.claude/subagents/test-runner.json" << 'EOF'
{
    "name": "test-runner",
    "description": "Testing specialist for unit, integration, and e2e tests. Ensures comprehensive test coverage and CI/CD integration.",
    "tools": ["Read", "Write", "Edit", "Bash", "Grep"],
    "system_prompt": "You are a testing specialist. Your responsibilities:\n- Write comprehensive unit tests (>80% coverage)\n- Create integration tests for all APIs\n- Implement e2e tests for critical user flows\n- Set up continuous testing in CI/CD\n- Fix failing tests immediately\n\nNEVER mark a feature complete without tests.\nReport test results to .orchestrator/test_results.log",
    "proactive": true
}
EOF
}

# DevOps sub-agent
create_devops_agent() {
    local project_dir="$1"
    cat > "$project_dir/.claude/subagents/devops-engineer.json" << 'EOF'
{
    "name": "devops-engineer",
    "description": "DevOps specialist for Docker, Kubernetes, CI/CD. Handles containerization, deployment, and infrastructure.",
    "tools": ["Read", "Write", "Edit", "Bash"],
    "system_prompt": "You are a DevOps specialist. Focus on:\n- Dockerfile and docker-compose.yml creation\n- CI/CD pipeline configuration\n- Environment variable management\n- Deployment scripts\n- Monitoring and logging setup\n\nEnsure all services are containerized.\nDocument deployment process in docs/deployment.md",
    "proactive": true
}
EOF
}

# Code reviewer sub-agent (leveraging Claude's PR review capabilities)
create_code_reviewer_agent() {
    local project_dir="$1"
    cat > "$project_dir/.claude/subagents/code-reviewer.json" << 'EOF'
{
    "name": "code-reviewer",
    "description": "Expert code reviewer focusing on quality, security, and maintainability. Automatically reviews all code changes.",
    "tools": ["Read", "Grep", "Bash"],
    "system_prompt": "You are an expert code reviewer. Review all code for:\n- Security vulnerabilities\n- Performance issues\n- Code smells and anti-patterns\n- Missing error handling\n- Insufficient test coverage\n\nBe constructive but thorough. Focus on actual bugs, not style.\nLog reviews to .orchestrator/code_reviews.log",
    "proactive": true
}
EOF
}

# Create orchestrator configuration
create_orchestrator_config() {
    local project_dir="$1"
    cat > "$project_dir/.claude/orchestrator.json" << 'EOF'
{
    "subagents": [
        "frontend-specialist",
        "backend-specialist",
        "database-architect",
        "test-runner",
        "devops-engineer",
        "code-reviewer"
    ],
    "delegation_rules": {
        "*.jsx|*.tsx|*.vue|*.css": "frontend-specialist",
        "api/*|routes/*|controllers/*": "backend-specialist",
        "migrations/*|schema/*": "database-architect",
        "*.test.*|*.spec.*": "test-runner",
        "Dockerfile|docker-compose.yml|.github/*": "devops-engineer",
        "review_needed": "code-reviewer"
    },
    "coordination": {
        "message_relay": true,
        "shared_context": ".orchestrator/",
        "test_on_change": true
    }
}
EOF
}

# Launch Claude Code with sub-agents
launch_claude_with_subagents() {
    local project_dir="$1"
    local initial_prompt="$2"
    
    # Create CLAUDE.md for project context
    cat > "$project_dir/CLAUDE.md" << EOF
# Project Context

This project uses TACO orchestration with Claude Code sub-agents.

## Available Sub-Agents
- frontend-specialist: UI/UX implementation
- backend-specialist: API and server logic
- database-architect: Schema and data layer
- test-runner: Comprehensive testing
- devops-engineer: Deployment and infrastructure
- code-reviewer: Automatic code review

## Coordination
- Use .orchestrator/ for shared state
- Register services in connections.json
- Log test results to test_results.log
- All builds must pass before completion

## Testing Requirements
- Unit tests: >80% coverage
- Integration tests: All APIs
- E2E tests: Critical flows
- Performance tests: Key operations

Initial Request: $initial_prompt
EOF
    
    # Launch Claude Code with extended thinking for complex orchestration
    echo "Launching Claude Code with sub-agents..."
    echo "Use 'think harder' for complex architectural decisions"
    
    # Start Claude Code in the project directory
    cd "$project_dir"
    claude --continue "ultrathink and orchestrate: $initial_prompt"
}

# Monitor sub-agent activity
monitor_subagent_activity() {
    local project_dir="$1"
    
    # Watch for sub-agent delegations
    tail -f "$project_dir/.claude/activity.log" 2>/dev/null | while read -r line; do
        if [[ "$line" =~ "Delegating to" ]]; then
            echo -e "${CYAN}🤖 Sub-agent activated: ${line}${NC}"
        elif [[ "$line" =~ "Test passed" ]]; then
            echo -e "${GREEN}✅ ${line}${NC}"
        elif [[ "$line" =~ "Test failed" ]]; then
            echo -e "${RED}❌ ${line}${NC}"
        fi
    done
}

# Integration with existing TACO monitoring
integrate_with_taco_monitoring() {
    local project_dir="$1"
    
    # Bridge Claude Code sub-agents with TACO's monitoring
    cat > "$project_dir/.orchestrator/subagent_bridge.sh" << 'EOF'
#!/usr/bin/env bash
# Bridge between Claude Code sub-agents and TACO monitoring

# Watch for sub-agent updates
watch_subagent_updates() {
    inotifywait -m -r "$1/.claude/subagents/" -e modify |
    while read path action file; do
        echo "[SUBAGENT] $file updated" >> "$1/.orchestrator/orchestrator.log"
    done
}

# Sync test results
sync_test_results() {
    while true; do
        if [ -f "$1/.claude/test_results.json" ]; then
            jq -r '.[] | "\(.name): \(.status)"' "$1/.claude/test_results.json" > "$1/.orchestrator/test_results.log"
        fi
        sleep 5
    done
}

# Main
watch_subagent_updates "$1" &
sync_test_results "$1" &
wait
EOF
    chmod +x "$project_dir/.orchestrator/subagent_bridge.sh"
}