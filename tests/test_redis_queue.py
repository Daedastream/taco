"""Tests for Redis queue."""

import pytest

from taco.models import CommandPriority, CommandType
from taco.redis_queue import RedisQueue


@pytest.fixture
async def redis_queue():
    """Create Redis queue instance for testing."""
    queue = RedisQueue(host="localhost", port=6379, db=15)  # Use test DB
    
    await queue.initialize()
    
    await queue.redis.flushdb()
    
    yield queue
    
    await queue.redis.flushdb()
    await queue.close()


@pytest.mark.asyncio
async def test_enqueue_command(redis_queue):
    """Test enqueueing a command."""
    cmd_id = await redis_queue.enqueue_command(
        target="taco:3.0",
        message="Test message",
        priority=CommandPriority.NORMAL,
    )

    assert cmd_id.startswith("cmd_")

    stats = await redis_queue.get_queue_stats()
    assert stats["pending"] > 0
    assert stats["enqueued"] == 1


@pytest.mark.asyncio
async def test_mark_completed(redis_queue):
    """Test marking command as completed."""
    cmd_id = await redis_queue.enqueue_command(
        target="taco:3.0",
        message="Test message",
    )

    await redis_queue.mark_completed(cmd_id, success=True)

    stats = await redis_queue.get_queue_stats()
    assert stats["executed"] == 1
    assert stats["failed"] == 0


@pytest.mark.asyncio
async def test_mark_failed(redis_queue):
    """Test marking command as failed."""
    cmd_id = await redis_queue.enqueue_command(
        target="taco:3.0",
        message="Test message",
    )

    await redis_queue.mark_completed(cmd_id, success=False)

    stats = await redis_queue.get_queue_stats()
    assert stats["failed"] == 1
    assert stats["executed"] == 0


@pytest.mark.asyncio
async def test_agent_state(redis_queue):
    """Test storing and retrieving agent state."""
    agent_state = {
        "window": "3",
        "name": "frontend_dev",
        "role": "Build UI",
        "status": "active",
    }

    await redis_queue.set_agent_state("frontend_dev", agent_state)

    retrieved = await redis_queue.get_agent_state("frontend_dev")

    assert retrieved is not None
    assert retrieved[b"name"].decode() == "frontend_dev"
    assert retrieved[b"window"].decode() == "3"


@pytest.mark.asyncio
async def test_service_info(redis_queue):
    """Test storing and retrieving service info."""
    service_info = {
        "name": "frontend",
        "port": "3000",
        "url": "http://localhost:3000",
        "health": "healthy",
    }

    await redis_queue.set_service_info("frontend", service_info)

    services = await redis_queue.get_all_services()

    assert "frontend" in services
    assert services["frontend"][b"port"].decode() == "3000"


@pytest.mark.asyncio
async def test_get_nonexistent_agent(redis_queue):
    """Test getting state for non-existent agent."""
    state = await redis_queue.get_agent_state("nonexistent")

    assert state is None
