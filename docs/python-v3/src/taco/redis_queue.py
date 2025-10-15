"""Redis-based command queue using Redis Streams."""

import asyncio
import logging
import uuid
from datetime import datetime
from typing import AsyncIterator, Optional

import redis.asyncio as redis

from .models import CommandPriority, CommandType, TmuxCommand

logger = logging.getLogger(__name__)


class RedisQueue:
    """Redis-based command queue with streams and pub/sub."""

    STREAM_COMMANDS = "commands:queue"
    STREAM_COMPLETED = "commands:completed"
    STREAM_FAILED = "commands:failed"
    PUBSUB_EVENTS = "monitor:events"
    CONSUMER_GROUP = "taco-executors"
    CONSUMER_NAME = "executor-1"

    def __init__(
        self, host: str = "localhost", port: int = 6379, db: int = 0
    ) -> None:
        """
        Initialize Redis queue.

        Args:
            host: Redis host
            port: Redis port
            db: Redis database number
        """
        self.redis = redis.Redis(host=host, port=port, db=db, decode_responses=False)
        self._running = False

    async def initialize(self) -> None:
        """Initialize Redis streams and consumer groups."""
        try:
            await self.redis.xgroup_create(
                self.STREAM_COMMANDS,
                self.CONSUMER_GROUP,
                id="0",
                mkstream=True,
            )
            logger.info("Created consumer group for command queue")
        except redis.ResponseError as e:
            if "BUSYGROUP" not in str(e):
                raise

    async def enqueue_command(
        self,
        target: str,
        message: str,
        priority: CommandPriority = CommandPriority.NORMAL,
        cmd_type: CommandType = CommandType.TMUX_MESSAGE,
    ) -> str:
        """
        Enqueue a command to be executed.

        Args:
            target: Tmux target (e.g., "taco:3.0")
            message: Message to send
            priority: Command priority
            cmd_type: Type of command

        Returns:
            Command ID
        """
        cmd_id = f"cmd_{uuid.uuid4().hex[:12]}"

        cmd = TmuxCommand(
            id=cmd_id,
            type=cmd_type,
            target=target,
            message=message,
            priority=priority,
        )

        await self.redis.xadd(self.STREAM_COMMANDS, cmd.to_redis_dict())

        await self.redis.incr("metrics:commands:enqueued")

        await self._publish_event(
            f"command.enqueued: {cmd_id} → {target}"
        )

        logger.info(f"Enqueued command {cmd_id} to {target}")
        return cmd_id

    async def dequeue_commands(
        self, batch_size: int = 10, block_ms: int = 5000
    ) -> AsyncIterator[TmuxCommand]:
        """
        Dequeue commands from the stream.

        Args:
            batch_size: Number of commands to fetch per batch
            block_ms: Milliseconds to block waiting for commands

        Yields:
            Commands to execute
        """
        while True:
            try:
                results = await self.redis.xreadgroup(
                    self.CONSUMER_GROUP,
                    self.CONSUMER_NAME,
                    {self.STREAM_COMMANDS: ">"},
                    count=batch_size,
                    block=block_ms,
                )

                if not results:
                    continue

                for stream_name, messages in results:
                    for message_id, data in messages:
                        try:
                            cmd = TmuxCommand.from_redis_dict(data)
                            yield cmd

                            await self.redis.xack(
                                self.STREAM_COMMANDS,
                                self.CONSUMER_GROUP,
                                message_id,
                            )

                        except Exception as e:
                            logger.error(
                                f"Failed to process message {message_id}: {e}"
                            )
                            await self.redis.xadd(
                                self.STREAM_FAILED,
                                {
                                    "message_id": message_id,
                                    "error": str(e),
                                    "timestamp": datetime.utcnow().isoformat(),
                                },
                            )

            except Exception as e:
                logger.error(f"Error in dequeue loop: {e}", exc_info=True)
                await asyncio.sleep(1)

    async def mark_completed(self, cmd_id: str, success: bool = True) -> None:
        """
        Mark a command as completed.

        Args:
            cmd_id: Command ID
            success: Whether execution succeeded
        """
        stream = self.STREAM_COMPLETED if success else self.STREAM_FAILED

        await self.redis.xadd(
            stream,
            {
                "cmd_id": cmd_id,
                "timestamp": datetime.utcnow().isoformat(),
            },
        )

        metric = "executed" if success else "failed"
        await self.redis.incr(f"metrics:commands:{metric}")

        status = "completed" if success else "failed"
        await self._publish_event(f"command.{status}: {cmd_id}")

    async def _publish_event(self, event: str) -> None:
        """Publish event to monitoring channel."""
        await self.redis.publish(self.PUBSUB_EVENTS, event)

    async def get_queue_stats(self) -> dict[str, int]:
        """
        Get queue statistics.

        Returns:
            Dictionary with queue stats
        """
        pipeline = self.redis.pipeline()
        pipeline.xlen(self.STREAM_COMMANDS)
        pipeline.get("metrics:commands:enqueued")
        pipeline.get("metrics:commands:executed")
        pipeline.get("metrics:commands:failed")

        results = await pipeline.execute()

        return {
            "pending": int(results[0] or 0),
            "enqueued": int(results[1] or 0),
            "executed": int(results[2] or 0),
            "failed": int(results[3] or 0),
        }

    async def set_agent_state(
        self, agent_name: str, state: dict[str, str]
    ) -> None:
        """
        Store agent state in Redis.

        Args:
            agent_name: Name of the agent
            state: State dictionary
        """
        await self.redis.hset(f"agents:{agent_name}", mapping=state)

    async def get_agent_state(self, agent_name: str) -> Optional[dict[str, bytes]]:
        """
        Get agent state from Redis.

        Args:
            agent_name: Name of the agent

        Returns:
            Agent state dictionary or None
        """
        state = await self.redis.hgetall(f"agents:{agent_name}")
        return state if state else None

    async def set_service_info(
        self, service_name: str, info: dict[str, str]
    ) -> None:
        """
        Store service information.

        Args:
            service_name: Name of the service
            info: Service info dictionary
        """
        await self.redis.hset(f"services:{service_name}", mapping=info)

    async def get_all_services(self) -> dict[str, dict[str, bytes]]:
        """
        Get all registered services.

        Returns:
            Dictionary of service name to info
        """
        services = {}
        async for key in self.redis.scan_iter(match="services:*"):
            service_name = key.decode().split(":", 1)[1]
            info = await self.redis.hgetall(key)
            services[service_name] = info
        return services

    async def close(self) -> None:
        """Close Redis connection."""
        await self.redis.close()
