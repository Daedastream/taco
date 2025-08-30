# 🌮 TACO - Tmux Agent Command Orchestrator

TACO orchestrates multiple AI agents in tmux sessions to work collaboratively on software development projects. A "Mother" orchestrator agent analyzes your requirements and spawns specialized worker agents that coordinate through tmux messaging.

## Features

- **Multi-Agent Orchestration**: Mother agent analyzes requirements and spawns 2-10 specialized worker agents
- **Tmux-Based Communication**: Agents coordinate through tmux send-keys commands
- **Real-time Monitoring**: Live status dashboard showing agent activity and logs
- **Flexible Display Modes**: Choose between separate tmux windows or panes for agent display
- **Support for Multiple AI Models**: Can specify Claude, GPT-4, Gemini, or other CLI-based AI tools
- **Session State Management**: Saves and tracks orchestration state

## Prerequisites

- **tmux**: Terminal multiplexer for managing sessions
- **AI CLI tool**: At least one of:
  - `claude` - Anthropic's Claude CLI (recommended)
  - `gpt` - OpenAI CLI tool
  - `gemini` - Google's Gemini CLI
  - Or any CLI-based AI tool
- **bash**: Version 4.0 or higher (uses associative arrays)

### Installation of Prerequisites

macOS:
```bash
# Install newer bash (macOS ships with 3.2)
brew install bash tmux

# Install your preferred AI CLI tool
# For Claude: Follow Anthropic's installation instructions
```

Linux:
```bash
sudo apt-get install tmux

# Install your preferred AI CLI tool
```

## Installation

### Quick Install

```bash
git clone https://github.com/yourusername/taco.git
cd taco
./install.sh
```

### Manual Install

1. Clone the repository:
```bash
git clone https://github.com/yourusername/taco.git
cd taco
```

2. Run the installation script:
```bash
./install.sh
```

3. Add to your PATH (if not already):
```bash
export PATH="$HOME/.local/bin:$PATH"  # or /usr/local/bin
```

### System-wide Installation

```bash
sudo PREFIX=/usr/local ./install.sh
```

## Usage

### Basic Usage

Start TACO interactively:
```bash
taco
```

### Command Line Options

```bash
taco [options]

Options:
  -f, --file <path>       Load project description from file
  -p, --prompt <text>     Provide project description directly
  -m, --model <model>     Claude model to use (sonnet or opus, default: sonnet)
  --claude                Use Claude (default)
  --openai                Use OpenAI GPT-4
  --gemini                Use Google Gemini
  --anthropic-api         Use Anthropic API
  --custom <cmd>          Use custom AI command
  --panes                 Use panes instead of windows
  -h, --help             Show help message
  -v, --version          Show version information

Examples:
  taco -f project_spec.txt
  taco -p "Build a React app with Express backend"
  taco -m opus            # Use Claude Opus for more complex tasks
  taco -m sonnet          # Use Claude Sonnet (default, faster)
  taco --openai           # Use GPT-4 instead of Claude
  taco --panes            # Display agents in panes
  taco  # Interactive mode with default model (Sonnet)
```

### Project Description Examples

1. **Simple Web App**:
```
Build a todo list application with:
- React frontend with Material-UI
- Express.js REST API
- PostgreSQL database
- JWT authentication
- Comprehensive test coverage
```

2. **From File**:
```bash
# Create a detailed spec file
cat > myproject.txt << EOF
Create an e-commerce platform with:
- Next.js frontend with TypeScript
- GraphQL API using Apollo Server
- MongoDB database with Mongoose
- Stripe payment integration
- Admin dashboard
- Mobile-responsive design
- Real-time inventory updates
- Email notifications
- Comprehensive testing suite
EOF

# Run TACO with the file
taco -f myproject.txt
```

### Model Selection (Claude)

When using Claude as your AI backend, you can choose between two models:

- **Sonnet** (default): Faster response times, ideal for most development tasks
- **Opus**: More capable for complex architectural decisions and nuanced requirements

Set the model via:
1. Command line: `taco -m opus` or `taco -m sonnet`
2. Environment variable: `export TACO_CLAUDE_MODEL=opus`
3. Configuration file: Edit `~/.taco/settings.json`

The selected model will be used for both the Mother orchestrator and all spawned agents.

## How It Works

1. **Mother Orchestrator**: The main AI agent analyzes your project requirements and outputs a specification for what specialized agents are needed

2. **Agent Spawning**: TACO parses the Mother's specification and automatically creates 2-10 specialized agents in separate tmux windows/panes:
   - Frontend developers
   - Backend developers
   - Database architects
   - Testing engineers
   - DevOps engineers
   - Any other specialized roles the Mother deems necessary

3. **Coordination**: The Mother agent enters "coordination mode" and orchestrates the worker agents by:
   - Sending tasks via tmux send-keys commands
   - Assigning workspaces and responsibilities
   - Managing inter-agent communication

4. **Monitoring**: A real-time dashboard shows:
   - Agent status and activity
   - Communication logs
   - System state

## Configuration

### Environment Variables

```bash
# Session name (default: taco)
export ORCHESTRATOR_SESSION="myproject"

# Project directory (default: current directory)
export PROJECT_DIR="/path/to/project"

# Timeout for specifications (default: 45 seconds)
export ORCHESTRATOR_TIMEOUT=60

# Log level (default: INFO)
export ORCHESTRATOR_LOG_LEVEL="DEBUG"
```

### Configuration File

Create `~/.orchestrator/config`:
```bash
ORCHESTRATOR_TIMEOUT=60
ORCHESTRATOR_MAX_RETRIES=3
ORCHESTRATOR_LOG_LEVEL=INFO
```

## Project Structure

After running TACO, your project will have:

```
project-dir/
├── .orchestrator/
│   ├── orchestrator.log       # Main log file
│   ├── communication.log      # Agent messages
│   ├── state.json            # Session state
│   ├── agent_spec.txt        # Mother's agent specification
│   ├── parsed_agents.txt     # Parsed agent list
│   ├── mother_prompt.txt     # Initial prompt to Mother
│   └── show_status.sh        # Status monitor script
└── [workspace directories created by agents]
```

## Navigation

Once TACO is running:

- `Ctrl+b + 0`: Mother orchestrator
- `Ctrl+b + 1`: Status monitor
- `Ctrl+b + 2-9`: Agent windows
- `Ctrl+b + d`: Detach (keeps running)
- `Ctrl+b + arrows`: Navigate panes (in pane mode)

## Monitoring

The status monitor (window 1) shows:
- Session information
- Agent status and list
- Recent log messages
- Orchestration state
- Elapsed time

## Advanced Usage

### Working with Different AI Models

```bash
# Use GPT-4 instead of Claude
taco --openai

# Use Gemini
taco --gemini

# Use a custom command
taco --custom "my-ai-cli"
```

### Display Modes

```bash
# Use panes for compact display (max 8 agents)
taco --panes

# Use windows for unlimited agents (default)
taco
```

## Troubleshooting

### Common Issues

1. **"declare: -g: invalid option"**: Your bash version is too old. Install bash 4+ with `brew install bash` on macOS.

2. **"No space for new pane"**: Too many agents for pane mode. Use window mode instead (default).

3. **Agent not responding**: Check the orchestrator.log and the agent's tmux window

4. **Mother not generating specification**: Check mother_output_debug.txt for the Mother's actual output

### Debug Mode

Enable debug logging:
```bash
export ORCHESTRATOR_LOG_LEVEL=DEBUG
taco
```

### Logs

- Main log: `.orchestrator/orchestrator.log`
- Messages: `.orchestrator/communication.log`
- Mother output: `.orchestrator/mother_output_debug.txt`
- Agent specification: `.orchestrator/agent_spec.txt`

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Works with multiple AI CLI tools (Claude, GPT-4, Gemini, etc.)
- Inspired by the need for multi-agent AI orchestration
- Built on tmux for robust terminal session management

## Support

- Issues: GitHub Issues
- Documentation: This README
- Examples: See the examples/ directory

---

Happy orchestrating! 🌮