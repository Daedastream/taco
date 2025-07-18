# 🌮 TACO - Tmux Agent Command Orchestrator

TACO is a powerful orchestration tool that coordinates multiple Claude AI agents in tmux sessions to work collaboratively on software development projects. It provides automated agent management, inter-agent communication, testing coordination, and deployment support.

## Features

- **Multi-Agent Orchestration**: Automatically creates and manages multiple Claude agents working in parallel
- **Smart Communication**: Built-in message relay system for agent-to-agent and agent-to-mother communication
- **Test-Driven Development**: Comprehensive testing requirements enforced across all agents
- **Connection Registry**: Centralized service discovery and port management
- **Docker Support**: Automatic detection and configuration for containerized environments
- **Real-time Monitoring**: Live status dashboard showing agent activity, test results, and system health
- **Flexible Display Modes**: Choose between separate tmux windows or panes for agent display

## Prerequisites

- **tmux**: Terminal multiplexer for managing sessions
- **claude**: Anthropic's Claude CLI tool
- **bash**: Version 4.0 or higher (uses associative arrays)
- **jq**: (Optional but recommended) JSON processor for enhanced functionality

### Installation of Prerequisites

macOS:
```bash
brew install tmux jq
# Install Claude CLI from Anthropic
```

Linux:
```bash
sudo apt-get install tmux jq
# Install Claude CLI from Anthropic
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
  -f, --file <path>     Load project description from file
  -p, --prompt <text>   Provide project description directly
  -h, --help           Show help message
  -v, --version        Show version information

Examples:
  taco -f project_spec.txt
  taco -p "Build a React app with Express backend"
  taco  # Interactive mode
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

## How It Works

1. **Mother Orchestrator**: The main Claude agent that analyzes your project requirements and creates specialized worker agents

2. **Agent Creation**: Based on your project, Mother creates 2-10 specialized agents:
   - Frontend developers
   - Backend developers
   - Database architects
   - Mobile developers
   - QA/Testing engineers
   - DevOps engineers

3. **Workspace Organization**: Each agent gets its own workspace directory and focuses on its specific domain

4. **Communication Protocol**: Agents communicate through:
   - Message relay system
   - Shared connection registry
   - Direct tmux messaging

5. **Testing & Validation**: All agents must:
   - Write comprehensive tests
   - Validate endpoints with curl
   - Report test results
   - Fix failures immediately

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
│   ├── connections.json       # Service registry
│   ├── orchestrator.log       # Main log file
│   ├── communication.log      # Agent messages
│   ├── test_results.log       # Test outcomes
│   ├── validation.log         # Connection validation
│   ├── state.json            # Session state
│   ├── message_relay.sh      # Communication helper
│   ├── port_helper.sh        # Port management
│   ├── test_coordinator.sh   # Test runner
│   └── validate_connections.sh # Service validator
├── frontend/                  # Frontend code
├── backend/                   # Backend code
├── database/                  # Database schemas
├── testing/                   # Test suites
└── docker/                    # Docker configs
```

## Navigation

Once TACO is running:

- `Ctrl+b + 0`: Mother orchestrator
- `Ctrl+b + 1`: Status monitor
- `Ctrl+b + 2`: Test monitor
- `Ctrl+b + 3-9`: Agent windows
- `Ctrl+b + d`: Detach (keeps running)
- `Ctrl+b + arrows`: Navigate panes (in pane mode)

## Monitoring

The status monitor (window 1) shows:
- Session information
- Agent status
- Recent messages
- Test results
- Connection registry
- Build status
- Elapsed time

## Advanced Features

### Port Management

```bash
# Agents can allocate ports
$PROJECT_DIR/.orchestrator/port_helper.sh allocate myservice

# Check port allocation
$PROJECT_DIR/.orchestrator/port_helper.sh show
```

### Connection Validation

```bash
# Validate all service connections
$PROJECT_DIR/.orchestrator/validate_connections.sh
```

### Docker Integration

TACO automatically detects Docker environments and:
- Adjusts port ranges
- Uses container names instead of localhost
- Generates docker-compose.yml files
- Creates appropriate Dockerfiles

### Message Relay

Agents communicate using the relay system:
```bash
# Agent to Mother
$PROJECT_DIR/.orchestrator/message_relay.sh "[AGENT-3 → MOTHER]: API ready"

# Agent to Agent
$PROJECT_DIR/.orchestrator/message_relay.sh "[AGENT-3 → AGENT-4]: Database schema updated" 4
```

## Troubleshooting

### Common Issues

1. **"No space for new pane"**: Too many agents for pane mode. Use window mode instead.

2. **Port conflicts**: Check the connection registry and use port_helper.sh

3. **Agent not responding**: Check the orchestrator.log and agent's tmux pane

4. **Tests failing**: Check test_results.log and the test-monitor window

### Debug Mode

Enable debug logging:
```bash
export ORCHESTRATOR_LOG_LEVEL=DEBUG
taco
```

### Logs

- Main log: `.orchestrator/orchestrator.log`
- Messages: `.orchestrator/communication.log`
- Tests: `.orchestrator/test_results.log`

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

- Built for use with Anthropic's Claude AI
- Inspired by the need for better AI agent orchestration
- Thanks to the tmux and jq communities

## Support

- Issues: GitHub Issues
- Documentation: This README
- Examples: See the examples/ directory

---

Happy orchestrating! 🌮