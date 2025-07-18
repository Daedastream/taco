# TACO Quick Start Guide

Get up and running with TACO in 5 minutes!

## 1. Install TACO

```bash
# Clone and install
git clone https://github.com/yourusername/taco.git
cd taco
./install.sh

# Add to PATH if needed
export PATH="$HOME/.local/bin:$PATH"
```

## 2. Your First Project

### Interactive Mode (Recommended for beginners)

```bash
taco
```

Then type your project description:
```
> Build a simple blog with:
> - Next.js frontend
> - Node.js API
> - PostgreSQL database
> - Admin panel
> <press Enter on empty line>
```

### Command Line Mode

```bash
taco -p "Build a REST API with Express.js, MongoDB, and JWT authentication"
```

### From a File

```bash
echo "Create a chat application with React, Socket.io, and Redis" > chat-app.txt
taco -f chat-app.txt
```

## 3. What Happens Next

1. **Mother Creates Agents**: Watch as the Mother orchestrator analyzes your request and creates specialized agents

2. **Agents Start Working**: Each agent will begin working on their assigned tasks

3. **Monitor Progress**: 
   - Press `Ctrl+b + 1` to see the status monitor
   - Press `Ctrl+b + 0` to return to Mother
   - Press `Ctrl+b + 3-9` to see individual agents

4. **Agents Coordinate**: They'll communicate, share ports, and test each other's work

## 4. Navigation Cheat Sheet

| Key Combination | Action |
|----------------|---------|
| `Ctrl+b + 0` | Go to Mother orchestrator |
| `Ctrl+b + 1` | View status monitor |
| `Ctrl+b + 2` | View test monitor |
| `Ctrl+b + 3-9` | View agents |
| `Ctrl+b + d` | Detach (keeps running) |
| `Ctrl+b + [` | Scroll mode |
| `q` | Exit scroll mode |

## 5. Common Scenarios

### Web Application

```bash
taco -p "Build a task management app with React, Express, PostgreSQL, and real-time updates"
```

### API Service

```bash
taco -p "Create a microservice API with FastAPI, Redis caching, and OpenAPI documentation"
```

### Mobile App

```bash
taco -p "Build a React Native app with Expo, GraphQL backend, and push notifications"
```

## 6. Tips for Success

1. **Be Specific**: The more detailed your requirements, the better the agents perform

2. **Include Testing**: Always mention "with comprehensive tests" for best results

3. **Watch the Monitors**: Keep an eye on the status and test monitors

4. **Check Logs**: If something goes wrong, check `.orchestrator/orchestrator.log`

5. **Let Agents Work**: Don't interrupt agents while they're working

## 7. Example Full Session

```bash
# Start TACO
$ taco

# Enter your project
> Create an e-commerce site with:
> - Next.js frontend with Tailwind CSS
> - Stripe payment integration  
> - Admin dashboard
> - Product search
> - User authentication
> - Shopping cart
> - Order tracking
> <Enter>

# Confirm
Is this correct? (Y/n): Y

# Configuration
Create project in a new folder? (Y/n): Y
Enter folder name: my-shop
How many agents should I create?: <Enter for auto>
How should agents be displayed?: 1

# Watch the magic happen!
# Agents will be created and start working
# Navigate between windows to see progress
# Check the monitor for status updates
```

## 8. Troubleshooting Quick Fixes

**Agents not starting?**
```bash
# Check if tmux session exists
tmux ls

# Kill and restart if needed
tmux kill-session -t taco
```

**Port conflicts?**
```bash
# Check port allocations
cat .orchestrator/connections.json | jq .ports
```

**Want to see what agents are doing?**
```bash
# View agent 3's screen
tmux attach -t taco
<Ctrl+b + 3>
```

## Next Steps

- Read the full [README](../README.md) for detailed documentation
- Check [ARCHITECTURE.md](ARCHITECTURE.md) to understand how TACO works
- See [EXAMPLES.md](EXAMPLES.md) for more project templates

Happy orchestrating! 🌮