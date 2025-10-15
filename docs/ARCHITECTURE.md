# TACO Python Architecture

## Core Principle
**Tmux is the ONLY communication mechanism that works reliably with Claude.**

All agent-to-agent and agent-to-Mother communication MUST use the 3-step tmux protocol:
1. `tmux send-keys -t SESSION:WINDOW "message"`
2. `sleep 0.2`
3. `tmux send-keys -t SESSION:WINDOW Enter`

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         Redis                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Command Queue│  │  Pub/Sub     │  │  State Store │      │
│  │  (Streams)   │  │  (Monitor)   │  │   (Hashes)   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
           ▲                    ▲                   ▲
           │                    │                   │
┌──────────┴────────────────────┴───────────────────┴─────────┐
│                    TACO Orchestrator (Python)                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Spec Parser  │  │ Agent Manager│  │ Tmux Executor│      │
│  │   (jq/JSON)  │  │  (asyncio)   │  │  (3-step)    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└──────────────────────────────────────────────────────────────┘
           │                    │                   │
           ▼                    ▼                   ▼
┌─────────────────────────────────────────────────────────────┐
│                          Tmux Session                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Window 0 │  │ Window 1 │  │ Window 2 │  │ Window N │   │
│  │  Mother  │  │ Monitor  │  │ Agent 1  │  │ Agent N  │   │
│  │ (Claude) │  │ (Status) │  │ (Claude) │  │ (Claude) │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Agent Specification Generation
```
User Input → Mother Prompt → Claude (Window 0)
          ↓
JSON Spec Output (between AGENT_SPEC_JSON_START/END markers)
          ↓
jq parser → Validated AgentSpec dataclass
          ↓
Redis state store (agents:* hashes)
```

### 2. Command Execution (Redis Stream → Tmux)
```
Agent needs to send message → Python enqueues to Redis Stream
                            ↓
Command: {
  "type": "tmux_message",
  "target": "taco:3",
  "message": "[AGENT-4 → AGENT-3]: API ready",
  "id": "cmd_12345"
}
                            ↓
TmuxExecutor worker pulls from stream
                            ↓
Step 1: tmux send-keys -t taco:3 "[AGENT-4 → AGENT-3]: API ready"
Step 2: sleep 0.2
Step 3: tmux send-keys -t taco:3 Enter
                            ↓
Redis pub/sub: publish "commands:completed" cmd_12345
```

### 3. State Management
```
Redis Hashes:
  - agents:{window} → {name, role, status, workspace}
  - services:{name} → {port, url, health}
  - session:state → {project_dir, started_at, agent_count}

Redis Streams:
  - commands:queue → pending tmux commands
  - commands:completed → execution results
  
Redis Pub/Sub:
  - monitor:events → real-time status updates
```

## Module Structure

```
taco/
├── pyproject.toml              # Poetry/pip dependencies
├── src/
│   └── taco/
│       ├── __init__.py
│       ├── __main__.py         # CLI entry point
│       ├── models.py           # Dataclasses (AgentSpec, Command, etc)
│       ├── parser.py           # JSON spec parsing with jq
│       ├── orchestrator.py     # Main orchestration logic
│       ├── tmux_executor.py    # 3-step tmux command execution
│       ├── redis_queue.py      # Redis streams interface
│       ├── agent_manager.py    # Agent lifecycle management
│       └── monitoring.py       # Status dashboard generator
├── tests/
│   ├── test_parser.py
│   ├── test_tmux_executor.py
│   ├── test_redis_queue.py
│   └── fixtures/
│       └── sample_specs.json
└── taco/                       # Keep bash for tmux setup only
    ├── bin/taco               # Wrapper: calls python -m taco
    └── lib/
        └── taco-tmux.sh       # Pure tmux session management
```

## Key Design Decisions

### Why Redis?
- **Reliable message queue**: Streams provide at-least-once delivery
- **Atomic operations**: Prevents race conditions in port allocation
- **Pub/Sub monitoring**: Real-time status updates without polling
- **Fast**: In-memory, <1ms command enqueue/dequeue
- **Simple**: Single dependency, runs locally

### Why Keep Tmux Communication?
- **Only reliable method**: Direct stdin to Claude's REPL
- **Visual monitoring**: See all agents working in real-time
- **Session persistence**: Detach/reattach without losing state
- **No API dependency**: Works offline, no rate limits

### Why Python?
- **Type safety**: Dataclasses catch bugs at dev time
- **Async/await**: Natural fit for coordinating N agents
- **Testing**: pytest >>> bash test harness
- **Parsing**: JSON via jq subprocess, not bash regex hell
- **Maintainability**: 1,500 lines Python vs 6,800 lines bash

## Command Protocol

### Mandatory 3-Step Execution
```python
async def execute_tmux_command(target: str, message: str) -> None:
    """NEVER modify this - it's the only reliable way to send to Claude."""
    await run_command(["tmux", "send-keys", "-t", target, message])
    await asyncio.sleep(0.2)
    await run_command(["tmux", "send-keys", "-t", target, "Enter"])
```

### Redis Stream Format
```json
{
  "id": "1234567890-0",
  "type": "tmux_message",
  "target": "taco:3.0",
  "message": "[AGENT-4 → AGENT-3]: Database schema ready",
  "priority": "normal",
  "timestamp": "2025-01-09T12:34:56Z",
  "retry_count": 0
}
```

### Queue Guarantees
- Commands processed in FIFO order per agent
- Failed commands retry with exponential backoff (max 3 attempts)
- Dead letter queue for permanently failed commands
- Command execution logged to Redis for debugging

## Migration Strategy

### Phase 1: Python Core (Keep Bash Wrapper)
- ✅ Delete unused bash code
- Python modules for parsing, Redis, tmux execution
- Bash `taco` wrapper calls `python -m taco`
- Run pytest suite before each commit

### Phase 2: Full Python
- Replace bash main() with Python CLI
- Remove taco/lib/*.sh except tmux-specific helpers
- Performance testing: startup time, message latency

### Phase 3: Production Hardening
- Error recovery: handle Redis/tmux crashes
- Monitoring dashboard: web UI (optional)
- Load testing: 20+ agents, 1000+ commands/min

## Performance Targets

- Session startup: <5s (currently 15s+)
- Command enqueue: <1ms
- Command execution: ~200ms (tmux overhead)
- Parsing 10 agents: <100ms
- Memory per agent: <50MB Python process

## Testing Strategy

```python
# tests/test_tmux_executor.py
@pytest.mark.asyncio
async def test_three_step_protocol():
    """Verify tmux commands use mandatory 3-step protocol."""
    executor = TmuxExecutor()
    
    with patch('taco.tmux_executor.run_command') as mock:
        await executor.send_message("taco:3", "test message")
        
        assert mock.call_count == 3
        assert mock.call_args_list[0][0][0] == ["tmux", "send-keys", "-t", "taco:3", "test message"]
        assert mock.call_args_list[2][0][0] == ["tmux", "send-keys", "-t", "taco:3", "Enter"]

# tests/test_parser.py
def test_json_spec_parsing():
    """Parse JSON agent spec from Mother output."""
    spec_file = "fixtures/mother_output.txt"
    agents = parse_agent_spec(spec_file)
    
    assert len(agents) == 5
    assert agents[0].name == "frontend_dev"
    assert agents[0].window == 3
    assert "validator" in agents[0].notifies
```

## Security

- Redis: localhost only, no auth needed (local dev)
- Tmux: session isolation via named sessions
- Input sanitization: escape special chars in messages
- No eval(): Use subprocess.run() with arg arrays

## Observability

### Logs
```python
logger.info("agent.created", agent=name, window=window)
logger.error("tmux.failed", cmd=cmd, error=err, retry=count)
```

### Metrics (Redis counters)
- `commands:enqueued:total`
- `commands:executed:total`
- `commands:failed:total`
- `agents:active:count`

### Monitoring Dashboard
Real-time tmux window (Window 1):
```
═══════════════════════════════════════════════════════════════
  TACO Orchestration Monitor
═══════════════════════════════════════════════════════════════
  Session: taco-project-20250109
  Started: 2h 34m ago
  Agents: 7 active, 0 failed

  Command Queue:
    Pending: 3
    Processing: 2
    Completed: 1,247
    Failed: 0

  Recent Activity:
    12:34:56 [AGENT-3 → AGENT-4] API spec shared
    12:34:55 [AGENT-5 → MOTHER] Tests passing (42/42)
    12:34:52 [AGENT-6 → AGENT-3] Frontend build complete

  Service Registry:
    frontend: http://localhost:3000 (healthy)
    backend:  http://localhost:3001 (healthy)
    database: http://localhost:5432 (healthy)
═══════════════════════════════════════════════════════════════
```
