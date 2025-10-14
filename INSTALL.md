# 📦 TACO Installation Guide

## Quick Install (Recommended)

Install TACO globally using pipx:

```bash
# 1. Install pipx (if not already installed)
brew install pipx

# 2. Install TACO
pipx install taco-orchestrator

# 3. Verify installation
taco --version
```

**Done!** Now you can use `taco` from anywhere.

---

## Installation Methods

### Method 1: Install from PyPI (When Published)

```bash
# Install globally
pipx install taco-orchestrator

# Or in a virtual environment
pip install taco-orchestrator
```

### Method 2: Install from Local Build

```bash
cd /Users/louisxsheid/dev/taco

# Build the package
python3.13 -m build

# Install globally with pipx
pipx install dist/taco_orchestrator-3.0.0-py3-none-any.whl

# Or install in current environment
pip install dist/taco_orchestrator-3.0.0-py3-none-any.whl
```

### Method 3: Development Install

```bash
cd /Users/louisxsheid/dev/taco

# Create virtual environment
python3.13 -m venv .venv
source .venv/bin/activate

# Install in editable mode
pip install -e ".[dev]"

# Now taco command works (while venv is active)
taco --version
```

---

## Prerequisites

### Required

- **Python 3.11+** - `python3.13 --version`
- **Redis 7+** - `brew install redis`
- **tmux 3.0+** - `brew install tmux`
- **jq** - `brew install jq`
- **Claude CLI** - `claude --version`

### Install All Prerequisites (macOS)

```bash
brew install python@3.13 redis tmux jq
brew services start redis
```

---

## Verify Installation

```bash
# Check taco is installed
taco --version
# Output: TACO 3.0.0

# Check where it's installed
which taco
# Output: /Users/yourname/.local/bin/taco (pipx)
#     or: /path/to/venv/bin/taco (venv)

# Check Redis is running
redis-cli ping
# Output: PONG

# Check tmux is available
tmux -V
# Output: tmux 3.x

# Check jq is available
jq --version
# Output: jq-1.x

# Check Claude CLI
claude --version
# Output: claude x.x.x
```

---

## Usage

### After Global Install (pipx)

```bash
# Just run taco from anywhere
taco

# With options
taco -p "Build a todo app"
taco -f project_spec.txt
taco -m opus --debug
```

### After Venv Install

```bash
# Activate venv first
cd /path/to/taco
source .venv/bin/activate

# Then run taco
taco -p "Build a todo app"
```

---

## Installation Verification Checklist

✅ **Python 3.11+**
```bash
python3 --version  # Should be >= 3.11
```

✅ **TACO installed**
```bash
taco --version  # Should show: TACO 3.0.0
```

✅ **Redis running**
```bash
redis-cli ping  # Should return: PONG
```

✅ **Tmux available**
```bash
tmux -V  # Should show version
```

✅ **jq available**
```bash
jq --version  # Should show version
```

✅ **Claude CLI available**
```bash
claude --version  # Should show version
```

✅ **Run tests** (development only)
```bash
cd /Users/louisxsheid/dev/taco
source .venv/bin/activate
pytest -v  # Should pass 17/17 tests
```

---

## Uninstall

### Uninstall pipx installation

```bash
pipx uninstall taco-orchestrator
```

### Uninstall pip installation

```bash
pip uninstall taco-orchestrator
```

### Remove development environment

```bash
cd /Users/louisxsheid/dev/taco
rm -rf .venv dist build src/*.egg-info
```

---

## Troubleshooting

### "taco: command not found"

**If installed with pipx:**
```bash
# Check pipx path
pipx list

# Ensure ~/.local/bin is in PATH
echo $PATH | grep ".local/bin"

# If not, add to ~/.zshrc or ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"
```

**If installed in venv:**
```bash
# Make sure venv is activated
source .venv/bin/activate
which taco  # Should show venv path
```

### "Python version error"

```bash
# You need Python 3.11+
brew install python@3.13

# Use explicit version
python3.13 -m pipx install taco-orchestrator
```

### "Redis connection failed"

```bash
# Start Redis
brew services start redis

# Verify it's running
redis-cli ping

# Check status
brew services list | grep redis
```

### "No module named 'taco'"

```bash
# Reinstall the package
pipx uninstall taco-orchestrator
pipx install taco-orchestrator

# Or in venv
pip install --force-reinstall taco-orchestrator
```

---

## Distribution

### Build Package for Distribution

```bash
cd /Users/louisxsheid/dev/taco

# Build
python3.13 -m build

# Outputs:
# - dist/taco_orchestrator-3.0.0.tar.gz
# - dist/taco_orchestrator-3.0.0-py3-none-any.whl
```

### Upload to PyPI (Future)

```bash
# Install twine
pip install twine

# Upload to PyPI
twine upload dist/*

# Upload to TestPyPI first
twine upload --repository testpypi dist/*
```

### Share with Others

**Option 1: Share the wheel**
```bash
# Give them the .whl file
scp dist/taco_orchestrator-3.0.0-py3-none-any.whl user@host:

# They install with:
pipx install taco_orchestrator-3.0.0-py3-none-any.whl
```

**Option 2: Share from GitHub**
```bash
# Push to GitHub
git push origin master

# They install with:
pipx install git+https://github.com/yourusername/taco.git
```

---

## Current Installation Status

✅ **Installed globally with pipx**
- Location: `/Users/louisxsheid/.local/bin/taco`
- Version: `3.0.0`
- Python: `3.13.7`

✅ **Available system-wide**
```bash
# Works from any directory
cd ~
taco --version  # TACO 3.0.0
```

✅ **Development environment ready**
```bash
cd /Users/louisxsheid/dev/taco
source .venv/bin/activate
pytest  # 17/17 tests passing
```

---

## Next Steps

1. **Verify installation**: `taco --version`
2. **Start Redis**: `brew services start redis`
3. **Run a test project**: `taco -p "Build a simple todo app"`
4. **Read documentation**: `README.md`, `QUICKSTART.md`, `ARCHITECTURE.md`

---

**You can now use `taco` from anywhere on your system!** 🌮
