"""Data models for TACO orchestration."""

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional


class AgentStatus(str, Enum):
    """Agent lifecycle states."""

    PENDING = "pending"
    STARTING = "starting"
    ACTIVE = "active"
    FAILED = "failed"
    COMPLETED = "completed"


class CommandType(str, Enum):
    """Types of commands that can be queued."""

    TMUX_MESSAGE = "tmux_message"
    TMUX_KEYSTROKE = "tmux_keystroke"
    STATE_UPDATE = "state_update"


class CommandPriority(str, Enum):
    """Command execution priority."""

    LOW = "low"
    NORMAL = "normal"
    HIGH = "high"
    CRITICAL = "critical"


@dataclass
class AgentSpec:
    """Agent specification from Mother's output."""

    window: int
    name: str
    role: str
    depends_on: list[str] = field(default_factory=list)
    notifies: list[str] = field(default_factory=list)
    wait_for: list[str] = field(default_factory=list)
    workspace: Optional[str] = None
    status: AgentStatus = AgentStatus.PENDING

    def __post_init__(self) -> None:
        """Validate agent spec."""
        if self.window < 3:
            raise ValueError(f"Agent window must be >= 3 (got {self.window})")
        if not self.name or not self.name.strip():
            raise ValueError("Agent name cannot be empty")
        if not self.role or not self.role.strip():
            raise ValueError("Agent role cannot be empty")


@dataclass
class TmuxCommand:
    """Command to be executed via tmux."""

    id: str
    type: CommandType
    target: str
    message: str
    priority: CommandPriority = CommandPriority.NORMAL
    timestamp: datetime = field(default_factory=datetime.utcnow)
    retry_count: int = 0
    max_retries: int = 3

    def to_redis_dict(self) -> dict[str, str]:
        """Convert to Redis stream entry format."""
        return {
            "id": self.id,
            "type": self.type.value,
            "target": self.target,
            "message": self.message,
            "priority": self.priority.value,
            "timestamp": self.timestamp.isoformat(),
            "retry_count": str(self.retry_count),
            "max_retries": str(self.max_retries),
        }

    @classmethod
    def from_redis_dict(cls, data: dict[str, bytes]) -> "TmuxCommand":
        """Create from Redis stream entry."""
        return cls(
            id=data[b"id"].decode(),
            type=CommandType(data[b"type"].decode()),
            target=data[b"target"].decode(),
            message=data[b"message"].decode(),
            priority=CommandPriority(data[b"priority"].decode()),
            timestamp=datetime.fromisoformat(data[b"timestamp"].decode()),
            retry_count=int(data[b"retry_count"]),
            max_retries=int(data[b"max_retries"]),
        )


@dataclass
class ServiceInfo:
    """Service registration information."""

    name: str
    port: int
    url: str
    health: str = "unknown"
    last_check: Optional[datetime] = None

    def to_redis_dict(self) -> dict[str, str]:
        """Convert to Redis hash format."""
        return {
            "name": self.name,
            "port": str(self.port),
            "url": self.url,
            "health": self.health,
            "last_check": self.last_check.isoformat() if self.last_check else "",
        }


@dataclass
class SessionState:
    """Overall orchestration session state."""

    session_name: str
    project_dir: str
    started_at: datetime
    agent_count: int
    active_agents: int = 0
    failed_agents: int = 0
    commands_enqueued: int = 0
    commands_executed: int = 0
    commands_failed: int = 0

    def to_redis_dict(self) -> dict[str, str]:
        """Convert to Redis hash format."""
        return {
            "session_name": self.session_name,
            "project_dir": self.project_dir,
            "started_at": self.started_at.isoformat(),
            "agent_count": str(self.agent_count),
            "active_agents": str(self.active_agents),
            "failed_agents": str(self.failed_agents),
            "commands_enqueued": str(self.commands_enqueued),
            "commands_executed": str(self.commands_executed),
            "commands_failed": str(self.commands_failed),
        }
