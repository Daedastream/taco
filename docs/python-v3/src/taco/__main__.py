"""TACO CLI entry point."""

import argparse
import asyncio
import logging
import sys
from pathlib import Path

from . import __version__
from .orchestrator import TacoOrchestrator


class ColoredFormatter(logging.Formatter):
    """Colored log formatter."""
    
    COLORS = {
        'DEBUG': '\033[36m',      # Cyan
        'INFO': '\033[32m',       # Green
        'WARNING': '\033[33m',    # Yellow
        'ERROR': '\033[31m',      # Red
        'CRITICAL': '\033[35m',   # Magenta
    }
    RESET = '\033[0m'
    BOLD = '\033[1m'
    
    def format(self, record):
        color = self.COLORS.get(record.levelname, self.RESET)
        record.levelname = f"{self.BOLD}{color}{record.levelname}{self.RESET}"
        record.name = f"\033[90m{record.name}{self.RESET}"  # Gray
        return super().format(record)


def setup_logging(debug: bool = False) -> None:
    """Configure logging."""
    level = logging.DEBUG if debug else logging.INFO
    
    handler = logging.StreamHandler()
    handler.setFormatter(ColoredFormatter(
        fmt="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    ))
    
    logging.root.setLevel(level)
    logging.root.addHandler(handler)


def main() -> None:
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description="TACO - Tmux Agent Command Orchestrator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "-v", "--version",
        action="version",
        version=f"TACO {__version__}",
    )

    parser.add_argument(
        "-f", "--file",
        type=Path,
        help="Load project description from file",
    )

    parser.add_argument(
        "-p", "--prompt",
        type=str,
        help="Project description",
    )

    parser.add_argument(
        "-m", "--model",
        type=str,
        default="sonnet",
        choices=["sonnet", "opus"],
        help="Claude model to use (default: sonnet)",
    )

    parser.add_argument(
        "--session-name",
        type=str,
        default="taco",
        help="Tmux session name (default: taco)",
    )

    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable debug logging",
    )

    args = parser.parse_args()

    setup_logging(args.debug)
    logger = logging.getLogger(__name__)

    project_prompt = None
    if args.file:
        if not args.file.exists():
            logger.error(f"File not found: {args.file}")
            sys.exit(1)
        project_prompt = args.file.read_text()
        logger.info(f"Loaded project from {args.file}")
    elif args.prompt:
        project_prompt = args.prompt

    try:
        orchestrator = TacoOrchestrator(
            session_name=args.session_name,
            claude_model=args.model,
        )

        asyncio.run(orchestrator.run(project_prompt))

    except KeyboardInterrupt:
        logger.info("Interrupted by user")
        sys.exit(0)
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
