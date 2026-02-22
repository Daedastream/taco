# TACO

**Tmux Agent Command Orchestrator** — multi-agent AI orchestration in pure bash.

One script. Multiple Claude instances. Parallel development in tmux.

## What it does

You describe a project. TACO launches a "Mother" orchestrator that designs an agent architecture, then spawns specialized Claude CLI instances across tmux windows that build your project in parallel — coordinating through tmux's native IPC.

```
taco -p "Build a full-stack e-commerce app with React and Express"
```

Mother analyzes your request, designs the agent topology, and TACO spawns the agents:

```
┌─────────────────────────────────────────────────────┐
│ Window 0: Mother (orchestrator - coordinates all)   │
├─────────────┬─────────────┬─────────────────────────┤
│ Window 3:   │ Window 4:   │ Window 5:               │
│ project_    │ auth_       │ frontend_ui             │
│ setup       │ system      │                         │
├─────────────┼─────────────┼─────────────────────────┤
│ Window 6:   │ Window 7:   │ Window 8:               │
│ api_        │ payment_    │ integration_            │
│ endpoints   │ processing  │ tester                  │
└─────────────┴─────────────┴─────────────────────────┘
```

Each agent is a real Claude CLI session with full tool access. You can watch them work in real-time, tab into any agent, and intervene mid-task.

## Requirements

- `bash` (4.0+)
- `tmux`
- `jq`
- `envsubst` (from gettext)
- [Claude CLI](https://docs.anthropic.com/en/docs/claude-cli)

```bash
# macOS
brew install tmux jq gettext

# Linux
apt-get install tmux jq gettext-base
```

## Usage

```bash
# Clone and run
git clone https://github.com/Daedastream/taco.git
cd taco
./taco

# Or with a direct prompt
./taco -p "Build a chat app with WebSockets"

# Quick mode (skip questionnaire)
./taco -q

# From a file
./taco -f project-description.txt
```

## How it works

1. **You describe a project** — interactive, quick mode, or direct prompt
2. **Mother analyzes** — a Claude instance designs the optimal agent architecture
3. **Agents spawn** — TACO creates tmux windows and launches Claude CLI in each
4. **Parallel execution** — agents build simultaneously, coordinating via tmux
5. **Mother orchestrates** — delegates tasks, monitors progress, handles errors, commits code

The entire coordination protocol runs through `tmux send-keys` — no servers, no message queues, no middleware. Tmux *is* the message bus.

## Files

```
taco                              # the whole thing (1,131 lines of bash)
templates/
  mother-prompt.txt               # orchestrator behavior & agent design
  agent-prompt.txt                # worker agent operational protocol
  coordination-prompt.txt         # Mother's coordination mode activation
```

## License

MIT — Daedastream LLC
