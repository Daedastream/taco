# TACO Bash v3

Pure bash implementation of TACO v3 with **zero Python/Redis dependencies**.

## What is Bash v3?

This is a complete port of the Python v3 orchestrator to pure bash:
- ✅ **Same prompts** - Identical Mother, Agent, and Coordination prompts
- ✅ **Same functionality** - Full orchestration with JSON spec parsing
- ✅ **Same CLI** - Compatible command-line interface
- ✅ **Zero dependencies** - Only requires `bash`, `tmux`, `jq`, and `claude` CLI
- ✅ **Lightweight** - No Python runtime, no Redis server
- ✅ **Fast** - Direct tmux commands with no abstraction layers

## Quick Start

```bash
# Run bash v3 (from this branch)
./taco-v3

# Or with options
./taco-v3 -p "Build a todo app"
./taco-v3 -f project.txt -m opus
```

## Installation

```bash
# Required: jq for JSON parsing
brew install jq  # macOS
# or
apt-get install jq  # Linux

# Already have: bash, tmux, claude CLI
```

## Usage

```bash
# Interactive mode
./taco-v3

# From file
./taco-v3 -f project-description.txt

# Direct prompt
./taco-v3 -p "Create a weather dashboard with React and Express"

# With specific model
./taco-v3 -m opus -p "Build a chat application"

# With custom session name
./taco-v3 --session-name my-project -p "..."
```

## Architecture

```
taco-v3 (bash script)
├── CLI parsing & setup
├── Interactive prompt collection
├── Tmux session management
├── Mother agent initialization
├── JSON spec parsing (using jq)
├── Agent window creation
├── Prompt template rendering
└── Session coordination

taco/templates/
├── mother-prompt.txt       (331 lines)
├── agent-prompt.txt        (212 lines)
├── coordination-prompt.txt (512 lines)
└── extract-prompts.sh      (extraction script)
```

## Differences from Bash v2

**Bash v2** (`taco/bin/taco`):
- Older prompt templates
- Manual agent selection UI
- Legacy spec parsing
- Docker/connection registry features

**Bash v3** (`taco-v3`):
- **New comprehensive prompts** from Python v3
- Clean CLI interface
- JSON-first spec parsing (jq-based)
- Streamlined orchestration
- **Exact same prompts as Python v3**

## Differences from Python v3

| Feature | Python v3 | Bash v3 |
|---------|-----------|---------|
| **Prompts** | ✅ Comprehensive | ✅ **Identical** |
| **JSON Parsing** | jq via subprocess | ✅ jq directly |
| **Dependencies** | Python, Redis, pydantic, asyncio-mqtt | ✅ **Just jq** |
| **Speed** | ~2s startup | ✅ **Instant** |
| **Memory** | ~50MB (Python + libs) | ✅ **~5MB** |
| **Async** | Python asyncio | Bash with sleeps |
| **Type Safety** | Pydantic models | Bash arrays |

## Benefits of Bash v3

1. **No Python required** - Pure shell script
2. **No Redis required** - No external services
3. **Faster startup** - No Python import time
4. **Less memory** - No Python runtime overhead
5. **Simpler debugging** - Just bash + tmux
6. **Same power** - Identical prompts and functionality
7. **More portable** - Works anywhere bash + tmux exist

## When to Use Bash v3 vs Python v3

**Use Bash v3 when:**
- You want zero dependencies
- You're on a system without Python
- You want faster startup
- You prefer debugging bash over Python
- You don't need async orchestration

**Use Python v3 when:**
- You need type safety (Pydantic models)
- You want async/await patterns
- You're extending with Python libraries
- You prefer Python debugging tools

## Testing

```bash
# Test basic functionality
./taco-v3 --version

# Test prompt extraction
cd taco/templates
./extract-prompts.sh

# Test full orchestration
./taco-v3 -p "Build a simple React counter app"
```

## Files

```
taco-v3                          # Main bash script (~400 lines)
taco/templates/
├── mother-prompt.txt            # Mother orchestrator prompt
├── agent-prompt.txt             # Agent operation protocol
├── coordination-prompt.txt      # Mother coordination mode
└── extract-prompts.sh           # Extractor from Python source
```

## Implementation Notes

- Uses `jq` for robust JSON parsing (same as Python version)
- Template files extracted from Python orchestrator.py
- Variable substitution using `eval` with proper escaping
- Tmux communication uses same 3-step protocol
- Spec waiting with exponential backoff
- Colorized logging matching Python version

## Contributing

To update prompts:
1. Edit `/src/taco/orchestrator.py` (Python version)
2. Run `cd taco/templates && ./extract-prompts.sh`
3. Prompts automatically sync to bash version

## Future

- Bash v3 will become the primary version
- Python v3 kept for reference and async features
- Templates shared between both versions
