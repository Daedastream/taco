"""Tmux command executor with mandatory 3-step protocol.

CRITICAL: The 3-step protocol is the ONLY reliable way to communicate with Claude agents.
Never modify this without extensive testing.
"""

import asyncio
import logging
from typing import Optional

from .models import TmuxCommand

logger = logging.getLogger(__name__)


class TmuxExecutor:
    """Executes commands via tmux with mandatory 3-step protocol."""

    STEP_DELAY = 0.2

    async def execute_command(self, cmd: TmuxCommand) -> bool:
        """
        Execute a tmux command using the mandatory 3-step protocol.

        Steps:
        1. tmux send-keys -t TARGET "message"
        2. sleep 0.2
        3. tmux send-keys -t TARGET Enter

        Args:
            cmd: Command to execute

        Returns:
            True if successful, False otherwise
        """
        try:
            logger.debug(f"Executing command {cmd.id} to {cmd.target}")

            await self._send_message(cmd.target, cmd.message)

            logger.info(f"Command {cmd.id} executed successfully")
            return True

        except Exception as e:
            logger.error(f"Command {cmd.id} failed: {e}", exc_info=True)
            return False

    async def _send_message(self, target: str, message: str) -> None:
        """
        Send a message to a tmux target using the 3-step protocol.

        For long messages, uses tmux load-buffer to avoid command line length limits.

        Args:
            target: Tmux target (e.g., "taco:3.0")
            message: Message to send
        """
        # For messages longer than 10KB, use buffer approach to avoid arg length limits
        if len(message) > 10000:
            # Load message into tmux buffer via stdin
            process = await asyncio.create_subprocess_exec(
                "tmux", "load-buffer", "-",
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )

            stdout, stderr = await process.communicate(input=message.encode())

            if process.returncode != 0:
                error_msg = stderr.decode().strip()
                raise RuntimeError(f"tmux load-buffer failed: {error_msg}")

            # Paste buffer to target
            await self._run_tmux_command(["paste-buffer", "-t", target])
        else:
            # For shorter messages, use direct send-keys
            await self._run_tmux_command(["send-keys", "-t", target, "--", message])

        await asyncio.sleep(self.STEP_DELAY)

        await self._run_tmux_command(["send-keys", "-t", target, "Enter"])

    async def _run_tmux_command(self, args: list[str]) -> None:
        """
        Run a tmux command.

        Args:
            args: Command arguments (will be prepended with "tmux")

        Raises:
            RuntimeError: If tmux command fails
        """
        full_cmd = ["tmux"] + args

        process = await asyncio.create_subprocess_exec(
            *full_cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        stdout, stderr = await process.communicate()

        if process.returncode != 0:
            error_msg = stderr.decode().strip()
            raise RuntimeError(f"tmux command failed: {error_msg}")

        logger.debug(f"Tmux command executed: {' '.join(full_cmd)}")

    async def check_target_exists(self, target: str) -> bool:
        """
        Check if a tmux target (window/pane) exists.

        Args:
            target: Tmux target to check

        Returns:
            True if target exists, False otherwise
        """
        try:
            await self._run_tmux_command(["list-panes", "-t", target])
            return True
        except RuntimeError:
            return False

    async def capture_pane(
        self, target: str, history_lines: int = 3000
    ) -> Optional[str]:
        """
        Capture output from a tmux pane.

        Args:
            target: Tmux target to capture
            history_lines: Number of lines to capture from history

        Returns:
            Pane content or None if capture failed
        """
        try:
            process = await asyncio.create_subprocess_exec(
                "tmux",
                "capture-pane",
                "-t",
                target,
                "-p",
                "-S",
                f"-{history_lines}",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )

            stdout, stderr = await process.communicate()

            if process.returncode != 0:
                logger.error(f"Failed to capture pane {target}: {stderr.decode()}")
                return None

            return stdout.decode()

        except Exception as e:
            logger.error(f"Error capturing pane {target}: {e}")
            return None

    async def clear_pane(self, target: str) -> bool:
        """
        Clear a tmux pane.

        Args:
            target: Tmux target to clear

        Returns:
            True if successful, False otherwise
        """
        try:
            await self._run_tmux_command(["send-keys", "-t", target, "C-l"])
            return True
        except RuntimeError:
            return False
