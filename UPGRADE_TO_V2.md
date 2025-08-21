# 🚀 TACO v2.0 - Major Upgrade

## What's New in v2.0

### 🤖 Claude Sub-Agents Integration
- Automatic creation of specialized sub-agents (code-reviewer, test-runner, debugger, etc.)
- Sub-agents work in clean contexts to avoid pollution
- Proactive delegation based on task type
- Use `/agents` command within Claude to manage sub-agents

### 🔌 MCP (Model Context Protocol) Support
- Direct integration with filesystem, Git, Docker, Kubernetes
- PostgreSQL and Redis MCP servers
- Playwright for browser testing
- Linear for issue tracking
- Faster and more reliable than bash commands

### 🌐 Multi-Model Orchestration
Now supports 10+ AI models:
- **Claude** (with sub-agents, MCP, thinking modes)
- **OpenAI GPT-4** (function calling, vision)
- **Anthropic API** (direct API access)
- **Gemini** (multimodal, long context)
- **Llama** (local, offline, GPU-accelerated)
- **Mistral** (fast, efficient)
- **Codex** (GitHub Copilot)
- **Grok** (X.AI)
- **Perplexity** (web search enhanced)
- **Custom** agents (bring your own)

### 🎯 Hybrid Orchestration Mode
- Run 5-10 agents in PARALLEL (not sequential like pure sub-agents)
- Mix different AI models in one project
- 5-10x faster for large projects
- Visual monitoring via tmux

### 🪝 Advanced Hooks System
- **Pre-task hooks**: Auto-assign agents based on complexity
- **Post-task hooks**: Automatic validation and testing
- **Error hooks**: Auto-recovery mechanisms
- **Performance hooks**: Monitor and optimize in real-time

### ⚙️ Settings Management
- JSON-based configuration (`taco.settings.json`)
- Per-project and global settings
- Interactive configuration: `taco --configure`
- Settings migration for upgrades

### 🧠 Thinking Modes
Leverage Claude's thinking capabilities:
- `think` - Standard reasoning
- `think hard` - Deeper analysis
- `think harder` - Complex problem solving
- `ultrathink` - Maximum reasoning for extreme challenges

### 📊 Enhanced Monitoring
- Real-time metrics dashboard
- Token usage tracking
- Cost estimation
- Performance analytics
- Distributed tracing

## Installation

```bash
# Clean install
git clone https://github.com/yourusername/taco.git
cd taco
./install.sh

# Upgrade from v1.x
cd taco
git pull
./install.sh
```

## Quick Start

### 1. Basic Usage (Claude with Sub-Agents)
```bash
taco
# Choose option 1: Claude with Sub-Agents
```

### 2. Hybrid Mode (Multiple Parallel Agents)
```bash
taco --hybrid
# Or choose option 2 in interactive mode
```

### 3. Use Different Models
```bash
taco --openai      # Use GPT-4
taco --llama       # Use local Llama
taco --gemini      # Use Google Gemini
```

### 4. Configure Settings
```bash
taco --configure   # Interactive configuration
```

### 5. Custom Settings File
```bash
taco --settings my-project.json
```

## Environment Variables

Set these for different AI providers:
```bash
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-ant-..."
export GEMINI_API_KEY="..."
export MISTRAL_API_KEY="..."
export PERPLEXITY_API_KEY="..."
```

## Example: Building a Full-Stack App

### Using TACO v2.0 Hybrid Mode
```bash
taco --hybrid -p "Build a Netflix clone with React, Node.js, PostgreSQL, and Redis"
```

This will:
1. Launch 5-7 specialized agents in parallel
2. Each agent gets Claude sub-agents for specialized tasks
3. Frontend agent handles React + UI sub-agents
4. Backend agent handles APIs + database sub-agents
5. Testing agent runs comprehensive tests
6. All work simultaneously with real-time coordination

### Time Comparison
- **Sequential (old way)**: 6+ hours
- **TACO v2.0 Hybrid**: 1-2 hours
- **Speedup**: 3-6x faster

## Configuration File

Create `.taco/settings.json`:
```json
{
  "orchestration": {
    "mode": "hybrid",
    "max_agents": 10,
    "default_agent_type": "claude"
  },
  "agents": {
    "claude": {
      "sub_agents_enabled": true,
      "thinking_modes": {
        "default": "think"
      },
      "mcp_enabled": true
    }
  },
  "testing": {
    "mandatory": true,
    "min_coverage": 80
  }
}
```

## Advanced Features

### MCP Servers
```bash
# Enable specific MCP servers
taco --mcp-servers filesystem,git,docker,postgres
```

### Hooks
Create `.taco/hooks/pre/my-hook.sh`:
```bash
#!/bin/bash
echo "Running before task..."
# Your custom logic
```

### Sub-Agent Templates
Create `.taco/subagents/my-specialist.json`:
```json
{
  "name": "my-specialist",
  "description": "Custom specialist for specific tasks",
  "tools": ["Read", "Write", "Edit"],
  "proactive": true
}
```

## Migration from v1.x

1. Your existing TACO projects will work as-is
2. To use new features, update your prompts to specify agent types
3. Settings from v1.x are auto-migrated on first run
4. Old tmux-only mode still available (option 3)

## Performance Tips

1. **Use Hybrid Mode** for large projects (5+ components)
2. **Enable MCP** for infrastructure tasks (Docker, K8s)
3. **Enable Sub-Agents** for better task specialization
4. **Use appropriate thinking modes**:
   - Simple tasks: no thinking mode
   - Moderate: `think`
   - Complex: `think harder`
   - Extreme: `ultrathink`

## Troubleshooting

### Claude not found
- Claude is now optional
- You can use other agents: `--openai`, `--llama`, etc.

### API Key errors
- Set environment variables for your chosen providers
- Check `.taco/settings.json` for API key configuration

### Performance issues
- Reduce parallel agents: `--max-agents 5`
- Disable sub-agents: `--no-subagents`
- Use simpler models for basic tasks

## What Makes TACO v2.0 Special?

| Feature | TACO v2.0 | Claude Sub-Agents Only | Traditional |
|---------|-----------|------------------------|-------------|
| Parallel Execution | ✅ 5-10 agents | ❌ Sequential | ❌ Single |
| Multi-Model | ✅ 10+ models | ❌ Claude only | ❌ One model |
| Visual Monitoring | ✅ Tmux dashboard | ❌ Hidden | ❌ None |
| Speed (large projects) | 🚀 1-2 hours | 🐌 6+ hours | 🐌 8+ hours |
| Sub-Agents | ✅ Yes | ✅ Yes | ❌ No |
| MCP Support | ✅ Yes | ✅ Limited | ❌ No |
| Hooks System | ✅ Advanced | ❌ Basic | ❌ No |

## Support

- GitHub Issues: [Report bugs](https://github.com/yourusername/taco/issues)
- Documentation: See `/docs` directory
- Examples: See `/examples` directory

## License

MIT License - See LICENSE file

---

**TACO v2.0** - The future of AI agent orchestration is here! 🌮🚀