#!/usr/bin/env python3
"""
TACO Improved - Keep tmux, fix everything else
Hybrid approach: Python orchestration + tmux visualization
"""

import os
import json
import subprocess
import asyncio
from dataclasses import dataclass
from typing import List, Dict
import sqlite3
import time


@dataclass
class AgentSpec:
    window_id: int
    name: str
    role: str
    command: str
    workspace: str
    dependencies: List[str] = None


class TmuxOrchestrator:
    """Python orchestrator that still uses tmux for agent execution"""
    
    def __init__(self, session_name="taco"):
        self.session = session_name
        self.agents = {}
        self.db = sqlite3.connect(os.path.expanduser("~/.taco/state.db"))
        self.init_db()
        
    def init_db(self):
        """Initialize state database"""
        self.db.execute("""
            CREATE TABLE IF NOT EXISTS agents (
                id TEXT PRIMARY KEY,
                window_id INTEGER,
                status TEXT,
                started_at TIMESTAMP,
                cost REAL DEFAULT 0
            )
        """)
        self.db.execute("""
            CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                from_agent TEXT,
                to_agent TEXT,
                message TEXT,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        self.db.commit()
        
    def tmux(self, *args):
        """Execute tmux command"""
        cmd = ["tmux"] + list(args)
        return subprocess.run(cmd, capture_output=True, text=True)
        
    def create_session(self):
        """Create tmux session with proper layout"""
        # Kill existing session if exists
        self.tmux("kill-session", "-t", self.session)
        
        # Create new session with mother orchestrator
        self.tmux("new-session", "-d", "-s", self.session, "-n", "mother")
        
        # Create monitoring windows
        self.tmux("new-window", "-t", f"{self.session}:1", "-n", "status-monitor")
        self.tmux("new-window", "-t", f"{self.session}:2", "-n", "test-monitor")
        
        print(f"✅ Created tmux session: {self.session}")
        
    def spawn_agent(self, spec: AgentSpec):
        """Spawn agent in tmux window with better management"""
        
        # Create window
        self.tmux("new-window", "-t", f"{self.session}:{spec.window_id}", "-n", spec.name)
        
        # Set up workspace
        os.makedirs(spec.workspace, exist_ok=True)
        
        # Create agent prompt with better context
        prompt = self.create_smart_prompt(spec)
        
        # Send initialization commands
        target = f"{self.session}:{spec.window_id}"
        
        # Change to workspace
        self.tmux("send-keys", "-t", target, f"cd {spec.workspace}", "Enter")
        time.sleep(0.5)
        
        # Start agent with proper flags
        if "claude" in spec.command:
            # Add MCP servers, context, etc.
            command = f"{spec.command} --mcp-server filesystem --thinking-mode situational"
        else:
            command = spec.command
            
        self.tmux("send-keys", "-t", target, command, "Enter")
        time.sleep(2)
        
        # Send initial prompt
        self.send_to_agent(spec.window_id, prompt)
        
        # Track in database
        self.db.execute(
            "INSERT INTO agents (id, window_id, status, started_at) VALUES (?, ?, ?, datetime('now'))",
            (spec.name, spec.window_id, "running")
        )
        self.db.commit()
        
        print(f"🤖 Spawned {spec.name} in window {spec.window_id}")
        
    def create_smart_prompt(self, spec: AgentSpec) -> str:
        """Create intelligent prompt with context awareness"""
        
        prompt = f"""You are {spec.role} working on a collaborative project.

WORKSPACE: {spec.workspace}
WINDOW: {spec.window_id} 
SESSION: {self.session}

COMMUNICATION PROTOCOL:
- Send updates: echo "[{spec.name.upper()} → MOTHER]: message" >> ../.orchestrator/messages.log
- Read messages: tail -f ../.orchestrator/messages.log | grep "→ {spec.name.upper()}"
- Register services: echo "{{port: 3000, service: 'api'}}" >> ../.orchestrator/registry.json

COORDINATION:
- Check for conflicts before modifying shared files
- Write tests for all code
- Document your API endpoints
- Use the port helper for service allocation

Your specific tasks:
"""
        
        # Add role-specific instructions
        if "frontend" in spec.role.lower():
            prompt += """
- Build responsive UI components
- Connect to backend APIs once available
- Implement proper error handling
- Use the registered backend services"""
            
        elif "backend" in spec.role.lower():
            prompt += """
- Create RESTful APIs
- Set up database models  
- Register your endpoints
- Implement authentication"""
            
        elif "test" in spec.role.lower():
            prompt += """
- Write comprehensive tests
- Validate all endpoints
- Check integration points
- Report results to mother"""
            
        return prompt
        
    def send_to_agent(self, window_id: int, message: str):
        """Send message to specific agent via tmux"""
        target = f"{self.session}:{window_id}"
        
        # Clear line first
        self.tmux("send-keys", "-t", target, "C-u")
        time.sleep(0.1)
        
        # Use printf to handle multiline properly
        escaped = message.replace("'", "'\\''")
        self.tmux("send-keys", "-t", target, f"printf '%s\\n' '{escaped}'", "Enter")
        
    def create_message_relay(self):
        """Create improved message relay using Python"""
        
        relay_script = """#!/usr/bin/env python3
import sys
import json
import time
import sqlite3
from pathlib import Path

db_path = Path.home() / ".taco" / "state.db"
db = sqlite3.connect(db_path)

def send_message(from_agent, to_agent, message):
    # Log to database
    db.execute(
        "INSERT INTO messages (from_agent, to_agent, message) VALUES (?, ?, ?)",
        (from_agent, to_agent, message)
    )
    db.commit()
    
    # Also append to log file for backward compatibility
    with open(".orchestrator/messages.log", "a") as f:
        timestamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        f.write(f"{timestamp} [{from_agent} → {to_agent}]: {message}\\n")
    
    print(f"✓ Message sent from {from_agent} to {to_agent}")

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: relay.py <from> <to> <message>")
        sys.exit(1)
    
    send_message(sys.argv[1], sys.argv[2], sys.argv[3])
"""
        
        os.makedirs(".orchestrator", exist_ok=True)
        with open(".orchestrator/relay.py", "w") as f:
            f.write(relay_script)
        os.chmod(".orchestrator/relay.py", 0o755)
        
    def monitor_agents(self):
        """Monitor agent status and costs"""
        
        while True:
            # Check agent health
            result = self.tmux("list-windows", "-t", self.session, "-F", 
                             "#{window_index}:#{window_name}:#{pane_dead}")
            
            for line in result.stdout.strip().split("\n"):
                if line:
                    idx, name, dead = line.split(":")
                    if dead == "1":
                        print(f"⚠️  Agent {name} (window {idx}) has died")
                        
            # Check costs
            total_cost = self.db.execute(
                "SELECT SUM(cost) FROM agents"
            ).fetchone()[0] or 0
            
            if total_cost > 50:  # $50 limit
                print(f"💸 WARNING: Total cost ${total_cost:.2f} exceeds limit!")
                self.shutdown_agents()
                break
                
            time.sleep(5)
            
    def detect_conflicts(self):
        """Detect file conflicts between agents"""
        
        # Use git to track who's modifying what
        result = subprocess.run(
            ["git", "diff", "--name-only"],
            capture_output=True,
            text=True
        )
        
        modified_files = result.stdout.strip().split("\n")
        
        # Check which agents modified which files
        agent_files = {}
        for agent in self.agents.values():
            workspace_files = []
            for file in modified_files:
                if file.startswith(agent.workspace):
                    workspace_files.append(file)
            if workspace_files:
                agent_files[agent.name] = workspace_files
                
        # Find conflicts
        all_files = {}
        for agent, files in agent_files.items():
            for f in files:
                if f not in all_files:
                    all_files[f] = []
                all_files[f].append(agent)
                
        conflicts = {f: agents for f, agents in all_files.items() if len(agents) > 1}
        
        if conflicts:
            print("⚠️  File conflicts detected:")
            for file, agents in conflicts.items():
                print(f"  {file}: {', '.join(agents)}")
                
        return conflicts
        
    def run_orchestration(self, project_spec: str):
        """Main orchestration loop"""
        
        print(f"🌮 TACO (Improved) Starting...")
        
        # Create session
        self.create_session()
        
        # Create message relay
        self.create_message_relay()
        
        # Start mother orchestrator
        mother_prompt = f"""You are the Mother orchestrator for this project:

{project_spec}

Create 2-5 specialized agents. For each agent, output:
AGENT_SPEC_START
AGENT:<window_id>:<name>:<role description>
AGENT_SPEC_END

Monitor their progress and coordinate their work.
"""
        
        self.send_to_agent(0, mother_prompt)
        
        print(f"📺 Attach to session: tmux attach -t {self.session}")
        print(f"📊 Navigate: Ctrl+b + [0-9] to switch windows")
        
        # Start monitoring in background
        # asyncio.create_task(self.monitor_agents())
        

def main():
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: taco_improved.py '<project description>'")
        sys.exit(1)
        
    project_spec = sys.argv[1]
    
    orchestrator = TmuxOrchestrator()
    orchestrator.run_orchestration(project_spec)
    
    # Keep running
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n👋 Shutting down TACO...")


if __name__ == "__main__":
    main()