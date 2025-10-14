"""Tests for tmux executor - verifies mandatory 3-step protocol."""

import pytest
from unittest.mock import AsyncMock, call, patch

from taco.models import CommandType, TmuxCommand
from taco.tmux_executor import TmuxExecutor


@pytest.mark.asyncio
async def test_three_step_protocol():
    """Verify tmux commands use mandatory 3-step protocol."""
    executor = TmuxExecutor()
    target = "taco:3.0"
    message = "[AGENT-4 → AGENT-3]: Test message"

    with patch.object(executor, "_run_tmux_command", new=AsyncMock()) as mock_run:
        await executor._send_message(target, message)

        assert mock_run.call_count == 2, "Must make exactly 2 tmux calls"

        call_1_args = mock_run.call_args_list[0][0][0]
        assert call_1_args == ["send-keys", "-t", target, "--", message]

        call_2_args = mock_run.call_args_list[1][0][0]
        assert call_2_args == ["send-keys", "-t", target, "Enter"]


@pytest.mark.asyncio
async def test_execute_command_success():
    """Test successful command execution."""
    executor = TmuxExecutor()
    cmd = TmuxCommand(
        id="test_123",
        type=CommandType.TMUX_MESSAGE,
        target="taco:3.0",
        message="Test message",
    )

    with patch.object(executor, "_send_message", new=AsyncMock()) as mock_send:
        result = await executor.execute_command(cmd)

        assert result is True
        mock_send.assert_called_once_with("taco:3.0", "Test message")


@pytest.mark.asyncio
async def test_execute_command_failure():
    """Test command execution failure."""
    executor = TmuxExecutor()
    cmd = TmuxCommand(
        id="test_456",
        type=CommandType.TMUX_MESSAGE,
        target="taco:99.0",
        message="Test message",
    )

    with patch.object(
        executor, "_send_message", new=AsyncMock(side_effect=RuntimeError("tmux failed"))
    ):
        result = await executor.execute_command(cmd)

        assert result is False


@pytest.mark.asyncio
async def test_check_target_exists():
    """Test checking if tmux target exists."""
    executor = TmuxExecutor()

    with patch.object(executor, "_run_tmux_command", new=AsyncMock()):
        exists = await executor.check_target_exists("taco:0.0")
        assert exists is True

    with patch.object(
        executor, "_run_tmux_command", new=AsyncMock(side_effect=RuntimeError())
    ):
        exists = await executor.check_target_exists("taco:99.0")
        assert exists is False


@pytest.mark.asyncio
async def test_capture_pane():
    """Test capturing pane output."""
    executor = TmuxExecutor()
    expected_output = "Test output from pane"

    async def mock_create_subprocess(*args, **kwargs):
        mock_process = AsyncMock()
        mock_process.communicate.return_value = (
            expected_output.encode(),
            b"",
        )
        mock_process.returncode = 0
        return mock_process

    with patch("asyncio.create_subprocess_exec", side_effect=mock_create_subprocess):
        output = await executor.capture_pane("taco:0.0")

        assert output == expected_output
