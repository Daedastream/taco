# TACO Architecture

## Overview

TACO (Tmux Agent Command Orchestrator) is built as a modular system that orchestrates multiple Claude AI agents to work collaboratively on software projects. The architecture is designed for scalability, reliability, and ease of extension.

## Core Components

### 1. Module Structure

TACO is split into several focused modules:

- **taco-common.sh**: Core utilities, configuration, and logging
- **taco-agents.sh**: Agent creation and prompt generation
- **taco-pane-manager.sh**: Tmux window and pane management
- **taco-registry.sh**: Connection registry and port management
- **taco-messaging.sh**: Inter-agent communication
- **taco-testing.sh**: Test coordination and monitoring
- **taco-monitoring.sh**: Status display and state management
- **taco-docker.sh**: Docker integration and compose generation

### 2. Agent Hierarchy

```
┌─────────────────┐
│     Mother      │  (Window 0)
│  (Orchestrator) │
└────────┬────────┘
         │ Creates & Coordinates
         │
    ┌────┴────┬─────────┬─────────┬─────────┐
    │         │         │         │         │
┌───▼───┐┌───▼───┐┌───▼───┐┌───▼───┐┌───▼───┐
│Agent 1││Agent 2││Agent 3││Agent 4││Agent N│
└───────┘└───────┘└───────┘└───────┘└───────┘
  (Frontend)(Backend)(Database)(Testing)(DevOps)
```

### 3. Communication Flow

```
Agent A ──message──> Message Relay ──validate──> Agent B
   │                      │                         │
   └──update registry─────┼─────read registry──────┘
                          │
                    Logged to disk
```

## Key Design Decisions

### 1. Tmux-based Architecture

**Why Tmux?**
- Native terminal multiplexing
- Persistent sessions
- Easy navigation between agents
- Visual monitoring of all agents
- No additional dependencies

### 2. File-based Communication

**Advantages:**
- Simple and reliable
- Easy to debug
- Persistent message history
- No network dependencies
- Works across system restarts

### 3. Modular Shell Scripts

**Benefits:**
- Easy to understand and modify
- No compilation required
- Portable across Unix systems
- Can be sourced individually
- Simple testing

## Data Flow

### 1. Initialization

```
User Input → Mother Prompt → Agent Specification → Agent Creation → Agent Initialization
```

### 2. Runtime Communication

```
Agent Work → Test Execution → Result Reporting → Mother Coordination → Next Tasks
```

### 3. Service Discovery

```
Agent Starts Service → Allocate Port → Update Registry → Other Agents Discover → Connect
```

## State Management

### 1. Persistent State

- **state.json**: Session configuration and agent list
- **connections.json**: Service registry and port mappings
- ***.log files**: Append-only logs for debugging

### 2. Runtime State

- Tmux session state
- Agent process states
- Environment variables
- File system workspace

## Security Considerations

### 1. Process Isolation

- Each agent runs in its own tmux pane
- Workspace isolation by directory
- No shared memory between agents

### 2. Port Management

- Automatic port allocation prevents conflicts
- Registry prevents duplicate services
- Validation ensures services are accessible

### 3. Command Injection Prevention

- All user input is properly escaped
- File paths are validated
- Commands use arrays instead of string concatenation

## Extension Points

### 1. Adding New Modules

Create a new module in `lib/` and source it in the main script:
```bash
source "$TACO_HOME/lib/taco-mymodule.sh"
```

### 2. Custom Agent Types

Modify `create_mother_prompt()` to include new agent types in specifications.

### 3. Additional Communication Channels

Extend `message_relay.sh` to support new communication methods.

### 4. New Testing Frameworks

Add cases to `test_coordinator.sh` for different test runners.

## Performance Considerations

### 1. Scalability

- Supports 2-15 agents efficiently
- File-based communication scales linearly
- Tmux handles window management efficiently

### 2. Resource Usage

- Minimal CPU overhead (shell scripts)
- Memory usage proportional to agent count
- Disk usage for logs and state files

### 3. Bottlenecks

- Mother agent can become a coordination bottleneck
- File system I/O for large projects
- Terminal rendering for many panes

## Error Handling

### 1. Failure Detection

- Health checks via connection validation
- Test failure detection and routing
- Build error monitoring

### 2. Recovery Mechanisms

- Automatic retry with backoff
- Fallback communication methods
- State restoration from disk

### 3. Debugging Support

- Comprehensive logging at multiple levels
- Message history preservation
- State inspection tools

## Future Enhancements

### 1. Planned Features

- Web UI for monitoring
- Cloud deployment support
- Multi-project orchestration
- Agent templates

### 2. Architecture Evolution

- Plugin system for extensions
- Remote agent support
- Advanced scheduling algorithms
- Machine learning for agent optimization