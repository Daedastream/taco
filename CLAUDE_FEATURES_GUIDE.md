# 🤖 Complete Guide to Claude Features in TACO v2.0

## Table of Contents
1. [Claude Sub-Agents](#claude-sub-agents)
2. [MCP (Model Context Protocol)](#mcp-model-context-protocol)
3. [Thinking Modes](#thinking-modes)
4. [Hooks System](#hooks-system)
5. [Memory & Context Management](#memory--context-management)
6. [Headless Mode](#headless-mode)
7. [Prompt Caching](#prompt-caching)
8. [Real-World Examples](#real-world-examples)
9. [Best Practices](#best-practices)

---

## Claude Sub-Agents

### What are Sub-Agents?
Sub-agents are specialized AI assistants that Claude can create and delegate tasks to. Each sub-agent:
- Works in a **clean context** (doesn't pollute main conversation)
- Has **specialized expertise** for specific tasks
- Can be **proactively triggered** based on task type
- Operates with **restricted tool access** for safety

### How to Use Sub-Agents

#### 1. Automatic Sub-Agent Creation
When you start TACO with Claude, it automatically creates useful sub-agents:

```bash
taco -p "Build a React dashboard with authentication"
```

TACO will automatically create:
- `code-reviewer` - Reviews code for bugs and security issues
- `test-runner` - Writes and runs comprehensive tests
- `debugger` - Fixes errors and debugging issues

#### 2. Manual Sub-Agent Creation
Within a Claude session, use the `/agents` command:

```bash
# In Claude session
/agents create frontend-expert "Specialist in React, Vue, and modern CSS"
/agents create api-architect "Expert in RESTful and GraphQL API design"
/agents create performance-optimizer "Specialist in web performance and optimization"
```

#### 3. Sub-Agent Templates
TACO comes with pre-configured sub-agent templates:

```json
// Located in .taco/subagents/templates/
{
  "code-reviewer": {
    "description": "Expert code review specialist",
    "tools": ["Read", "Grep", "Bash"],
    "proactive": true,  // Automatically activates for code reviews
    "triggers": ["review", "check", "audit"]
  },
  "test-runner": {
    "description": "Comprehensive testing specialist",
    "tools": ["Read", "Write", "Edit", "Bash"],
    "proactive": true,
    "triggers": ["test", "spec", "coverage"]
  }
}
```

#### 4. Invoking Sub-Agents
Three ways to use sub-agents:

```bash
# 1. Automatic delegation (Claude decides)
"Review this code for security issues"  # Automatically uses code-reviewer

# 2. Explicit request
"Use the test-runner subagent to write unit tests for this function"

# 3. Direct invocation
/agents invoke test-runner "Write integration tests for the API"
```

### Sub-Agent Example: Building a Full-Stack App

```bash
# Start TACO with sub-agents enabled
taco --hybrid -p "Build a task management app with React and Node.js"

# TACO automatically creates these sub-agents:
# - frontend-specialist (React, UI/UX)
# - backend-specialist (Node.js, APIs)
# - database-architect (Schema design)
# - test-runner (Testing)
# - devops-engineer (Deployment)

# Each agent works in parallel with its own sub-agents!
```

---

## MCP (Model Context Protocol)

### What is MCP?
MCP is Anthropic's protocol for connecting Claude to external tools and services. Instead of using bash commands, Claude can directly interface with:
- File systems
- Git repositories
- Docker containers
- Databases
- Cloud services

### Enabling MCP Servers

#### 1. Default MCP Servers
TACO automatically enables common MCP servers:

```bash
# These are enabled by default:
- filesystem  # Direct file operations
- git        # Git operations without bash
- docker     # Container management
- postgres   # Database queries
- redis      # Cache operations
```

#### 2. Configure MCP in Settings
Edit `.taco/settings.json`:

```json
{
  "communication": {
    "mcp_enabled": true,
    "mcp_servers": [
      "filesystem",
      "git",
      "docker",
      "kubernetes",
      "postgres",
      "redis",
      "playwright",  // Browser automation
      "linear"       // Issue tracking
    ]
  }
}
```

#### 3. Using MCP in Projects

```bash
# Start TACO with specific MCP servers
taco --mcp-servers filesystem,git,docker,postgres

# In your project, Claude can now:
# - Read/write files directly (no cat/echo needed)
# - Perform git operations (no git commands needed)
# - Manage Docker containers
# - Query databases directly
```

### MCP Example: Database-Driven App

```bash
# Start TACO with database MCP
taco -p "Build a blog with PostgreSQL"

# Claude can now:
# 1. Create tables directly via MCP
# 2. Run queries without psql
# 3. Manage migrations
# 4. Test database operations

# No need for bash commands like:
# psql -U user -d database -c "CREATE TABLE..."
# Claude uses MCP directly!
```

---

## Thinking Modes

### What are Thinking Modes?
Claude 4 models can engage in different levels of reasoning before responding. More thinking = better solutions for complex problems.

### Available Thinking Modes

| Mode | Command | Use Case | Thinking Time |
|------|---------|----------|---------------|
| Standard | (default) | Simple tasks | Instant |
| Think | `think` | Moderate complexity | ~5 seconds |
| Think Hard | `think hard` | Complex problems | ~15 seconds |
| Think Harder | `think harder` | Very complex | ~30 seconds |
| Ultrathink | `ultrathink` | Extreme challenges | ~60 seconds |

### Using Thinking Modes

#### 1. Command Line
```bash
# Specify thinking mode when starting
taco --think think_hard -p "Design a microservices architecture"
taco --think ultrathink -p "Optimize this distributed system"
```

#### 2. In Session
```bash
# Within Claude session
"think hard and refactor this legacy codebase"
"ultrathink and design a fault-tolerant payment system"
```

#### 3. Automatic Selection
TACO can auto-select thinking mode based on task complexity:

```bash
# Simple task -> standard thinking
taco -p "Add a button to the homepage"

# Complex task -> automatically uses deeper thinking
taco -p "Redesign the entire application architecture for 10x scale"
```

### Thinking Mode Examples

#### Example 1: Simple Fix (Standard)
```bash
taco -p "Fix the typo in README.md"
# Uses standard mode - instant response
```

#### Example 2: Feature Implementation (Think)
```bash
taco --think think -p "Add user authentication to the app"
# Uses think mode - considers security, sessions, passwords
```

#### Example 3: Architecture Design (Ultrathink)
```bash
taco --think ultrathink -p "Convert monolith to microservices"
# Uses ultrathink - analyzes dependencies, designs services, plans migration
```

---

## Hooks System

### What are Hooks?
Hooks are automated scripts that run at specific points in the TACO lifecycle. They enable:
- Automatic agent assignment
- Performance monitoring
- Error recovery
- Custom workflows

### Types of Hooks

#### 1. Pre-Task Hooks
Run before tasks start:

```bash
# .taco/hooks/pre/auto-assign.sh
#!/bin/bash
# Automatically assign agents based on task complexity

TASK="$1"
if [[ "$TASK" =~ "complex" ]]; then
    export TACO_AGENT_COUNT=10
    export THINKING_MODE="ultrathink"
else
    export TACO_AGENT_COUNT=3
    export THINKING_MODE="think"
fi
```

#### 2. Post-Task Hooks
Run after task completion:

```bash
# .taco/hooks/post/validate.sh
#!/bin/bash
# Run tests and validation

npm test
npm run lint
npm run type-check

# Check coverage
if [ $(npm run coverage | grep "Statements" | grep -o "[0-9]*%" | tr -d '%') -lt 80 ]; then
    echo "Warning: Test coverage below 80%"
    # Trigger test-runner sub-agent
fi
```

#### 3. Error Hooks
Handle failures automatically:

```bash
# .taco/hooks/error/auto-recovery.sh
#!/bin/bash
ERROR_TYPE="$1"

case $ERROR_TYPE in
    "test_failed")
        echo "Tests failed, delegating to test-runner sub-agent"
        # Auto-trigger test fixing
        ;;
    "build_failed")
        echo "Build failed, analyzing error..."
        # Auto-trigger debugger sub-agent
        ;;
esac
```

### Creating Custom Hooks

```bash
# Register a custom hook
taco --register-hook pre my-custom-hook /path/to/script.sh

# Create hook chain for complex workflows
cat > .taco/hooks/chains/deployment.json << EOF
{
  "name": "deployment",
  "hooks": [
    {"type": "pre", "name": "run-tests"},
    {"type": "pre", "name": "build"},
    {"type": "post", "name": "deploy"},
    {"type": "post", "name": "smoke-test"}
  ]
}
EOF
```

---

## Memory & Context Management

### Context Windows
Claude 4 has a 200k token context window, and TACO optimizes its usage:

#### 1. Semantic Search
```bash
# Enable semantic search for large codebases
taco --semantic-search -p "Refactor the payment system"

# Claude can now search millions of lines efficiently
# Only relevant code is brought into context
```

#### 2. Context Isolation
```bash
# Each sub-agent has isolated context
# Main agent: 50k tokens used
# Sub-agent 1: Fresh 200k context
# Sub-agent 2: Fresh 200k context
# Total available: 600k+ tokens across agents!
```

#### 3. Persistent Memory
```bash
# Enable SQLite memory
taco --memory sqlite -p "Long-term project"

# Claude remembers:
# - Previous decisions
# - Architectural choices
# - Test results
# - Error patterns
```

### CLAUDE.md Files
Special files that Claude automatically loads:

```markdown
# CLAUDE.md
Project context and rules for Claude.

## Architecture Decisions
- Use PostgreSQL for main database
- Redis for caching
- React for frontend
- Node.js + Express for API

## Coding Standards
- Use TypeScript
- 100% test coverage required
- Follow ESLint rules

## Do Not
- Never commit secrets
- Don't use deprecated APIs
- Avoid console.log in production
```

---

## Headless Mode

### What is Headless Mode?
Run Claude without interactive UI - perfect for CI/CD, automation, and scripts.

### Using Headless Mode

```bash
# Basic headless execution
taco --headless -p "Run tests and fix any failures" --output-format json

# In CI/CD pipeline
taco --headless \
  -p "Review PR and add comments" \
  --output-format stream-json \
  --timeout 300
```

### Headless Mode in GitHub Actions

```yaml
name: AI Code Review
on: [pull_request]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Install TACO
        run: |
          curl -L https://github.com/taco/install.sh | bash
          
      - name: AI Review
        run: |
          taco --headless \
            -p "Review this PR for bugs and security issues" \
            --output-format json > review.json
            
      - name: Post Comments
        run: |
          cat review.json | jq '.comments[]' | gh pr comment
```

---

## Prompt Caching

### What is Prompt Caching?
Claude can cache prompts for up to 1 hour, reducing latency and costs for repeated operations.

### Enabling Prompt Caching

```bash
# Enable in settings
{
  "agents": {
    "claude": {
      "cache_prompts": true,
      "cache_duration": 3600  // 1 hour
    }
  }
}
```

### Use Cases for Caching

```bash
# 1. Iterative Development
taco --cache -p "Keep improving this function"
# Subsequent calls reuse context - faster and cheaper

# 2. Multiple Agents on Same Codebase
taco --hybrid --cache -p "Each agent work on different components"
# All agents share cached understanding of codebase

# 3. Continuous Testing
taco --cache -p "Run tests every time code changes"
# Test context cached - instant test execution
```

---

## Real-World Examples

### Example 1: E-Commerce Platform

```bash
# Start TACO with full features
taco --hybrid \
     --think think_hard \
     --mcp-servers postgres,redis,stripe \
     -p "Build an e-commerce platform with:
         - Product catalog
         - Shopping cart
         - Payment processing (Stripe)
         - Order management
         - Admin dashboard
         - Email notifications"

# TACO will:
# 1. Create 7 parallel agents (frontend, backend, database, payments, admin, email, testing)
# 2. Each agent gets specialized sub-agents
# 3. Use MCP for direct database/cache operations
# 4. Apply think_hard mode for architecture decisions
# 5. Run hooks for testing and validation
```

#### What Happens:

**Window 3 (Frontend Lead)**
- Creates sub-agents: react-expert, css-specialist, ux-designer
- Builds product catalog UI
- Implements shopping cart
- Creates responsive design

**Window 4 (Backend Lead)**
- Creates sub-agents: api-designer, auth-specialist
- Designs RESTful APIs
- Implements business logic
- Sets up middleware

**Window 5 (Database Architect)**
- Uses PostgreSQL MCP directly
- Designs normalized schema
- Creates migrations
- Optimizes queries

**Window 6 (Payment Engineer)**
- Integrates Stripe via MCP
- Implements secure payment flow
- Handles webhooks
- Tests transactions

**Window 7 (Testing Lead)**
- Creates sub-agents: unit-tester, e2e-tester
- Writes comprehensive tests
- Ensures 90% coverage
- Runs continuous validation

### Example 2: Real-Time Chat Application

```bash
taco --hybrid \
     --semantic-search \
     --cache \
     -p "Build a Slack clone with:
         - Real-time messaging (WebSockets)
         - Channels and DMs
         - File sharing
         - User presence
         - Search functionality
         - Mobile responsive"

# Special features used:
# - Semantic search for finding similar chat implementations
# - Caching for iterative improvements
# - WebSocket MCP for real-time features
```

### Example 3: AI-Powered Code Migration

```bash
# Migrate large codebase from JavaScript to TypeScript
taco --hybrid \
     --think ultrathink \
     --semantic-search \
     --cache \
     -p "Migrate entire codebase from JavaScript to TypeScript:
         - Convert 500+ files
         - Add proper types
         - Fix type errors
         - Maintain functionality
         - Update tests"

# TACO creates specialized migration agents:
# - Type analyst (analyzes existing code patterns)
# - Migration specialist (converts JS to TS)
# - Type designer (creates interfaces and types)
# - Test updater (updates tests for TypeScript)
# - Validator (ensures no regressions)
```

### Example 4: DevOps Pipeline Setup

```bash
taco --mcp-servers docker,kubernetes,github \
     --headless \
     -p "Set up complete CI/CD pipeline:
         - Dockerize application
         - Create Kubernetes manifests
         - Set up GitHub Actions
         - Add monitoring (Prometheus)
         - Configure auto-scaling"

# Runs in headless mode for automation
# Uses MCP for direct Docker/K8s operations
# Creates everything without manual intervention
```

---

## Best Practices

### 1. Choosing the Right Mode

| Project Size | Recommended Setup |
|-------------|-------------------|
| Small (1-3 components) | Standard TACO with sub-agents |
| Medium (4-7 components) | Hybrid mode with think mode |
| Large (8+ components) | Hybrid + semantic search + caching |
| Enterprise | Full hybrid + ultrathink + all MCP servers |

### 2. Optimizing Performance

```bash
# For maximum speed on large projects:
taco --hybrid \              # Parallel execution
     --cache \               # Reuse context
     --semantic-search \     # Efficient code search
     --mcp-servers all \     # Direct tool access
     --no-subagents \        # Skip if not needed
     -p "Your project"
```

### 3. Debugging Issues

```bash
# Enable debug mode for troubleshooting
export ORCHESTRATOR_LOG_LEVEL=DEBUG
taco --settings debug.json -p "Project with issues"

# Check logs
tail -f .orchestrator/orchestrator.log
tail -f .orchestrator/communication.log
tail -f .orchestrator/mcp.log
```

### 4. Cost Optimization

```bash
# Reduce API costs:
1. Enable caching (--cache)
2. Use appropriate thinking modes (not always ultrathink)
3. Enable semantic search (only relevant code in context)
4. Use headless mode for automation
5. Leverage sub-agents (parallel but isolated contexts)
```

### 5. Security Best Practices

```bash
# Secure setup:
1. Never commit .env files
2. Use environment variables for API keys
3. Enable MCP for controlled tool access
4. Use restricted sub-agents for sensitive operations
5. Review generated code before deployment
```

---

## Advanced Configurations

### Custom Sub-Agent for Your Domain

```json
// .taco/subagents/financial-expert.json
{
  "name": "financial-expert",
  "description": "Expert in financial calculations, trading algorithms, and risk assessment",
  "tools": ["Read", "Write", "Bash"],
  "system_prompt": "You are a financial expert. Focus on:\n- Accurate calculations\n- Risk management\n- Regulatory compliance\n- Performance optimization\nNever make assumptions about financial data.",
  "proactive": true,
  "triggers": ["trading", "finance", "risk", "portfolio"]
}
```

### Complex Hook Chain

```json
// .taco/hooks/chains/production-deploy.json
{
  "name": "production-deploy",
  "hooks": [
    {"type": "pre", "name": "freeze-code", "timeout": 10},
    {"type": "pre", "name": "run-security-scan", "timeout": 300},
    {"type": "pre", "name": "run-all-tests", "timeout": 600},
    {"type": "pre", "name": "build-containers", "timeout": 300},
    {"type": "pre", "name": "backup-database", "timeout": 120},
    {"type": "action", "name": "deploy-to-staging", "timeout": 180},
    {"type": "post", "name": "smoke-tests", "timeout": 60},
    {"type": "post", "name": "deploy-to-production", "timeout": 180},
    {"type": "post", "name": "monitor-metrics", "timeout": 300},
    {"type": "error", "name": "rollback", "timeout": 60}
  ]
}
```

### MCP Server Configuration

```json
// .taco/mcp/custom-database.json
{
  "name": "custom-database",
  "type": "external",
  "executable": "mcp-custom-db",
  "config": {
    "connection_string": "${DATABASE_URL}",
    "pool_size": 20,
    "timeout": 30000,
    "ssl": true,
    "migrations_path": "./db/migrations",
    "seeds_path": "./db/seeds",
    "backup_schedule": "0 2 * * *"
  }
}
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Sub-Agents Not Activating
```bash
# Check if sub-agents are enabled
cat .taco/settings.json | jq '.agents.claude.sub_agents_enabled'

# Enable manually
taco --no-subagents=false  # Double negative enables them
```

#### 2. MCP Connection Failed
```bash
# Test MCP servers
taco --test-mcp

# Check specific server
mcp-doctor filesystem
mcp-doctor postgres
```

#### 3. Thinking Mode Too Slow
```bash
# Adjust timeout
export ORCHESTRATOR_TIMEOUT=120  # 2 minutes

# Or use lighter thinking mode
taco --think think  # Instead of ultrathink
```

#### 4. Context Window Exceeded
```bash
# Enable semantic search
taco --semantic-search

# Or split into smaller tasks
taco --split-tasks -p "Large project"
```

---

## Summary

TACO v2.0 with Claude's advanced features provides:

1. **Sub-Agents**: Specialized, clean-context assistants
2. **MCP**: Direct tool integration without bash
3. **Thinking Modes**: Adjustable reasoning depth
4. **Hooks**: Automated workflows
5. **Memory**: Persistent and semantic
6. **Headless**: CI/CD automation
7. **Caching**: Faster, cheaper operations

The combination of these features makes TACO the most powerful AI orchestration tool available, capable of handling everything from simple scripts to enterprise-scale applications.

**Remember**: TACO's true power comes from combining these features. Use hybrid mode for parallelism, sub-agents for specialization, MCP for direct tool access, and appropriate thinking modes for the task complexity.

---

*For more examples and updates, check the `/examples` directory and run `taco --help` for the latest commands.*