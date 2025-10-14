"""Agent specification parser using jq for JSON extraction."""

import json
import logging
import re
import subprocess
from pathlib import Path
from typing import Optional

from .models import AgentSpec

logger = logging.getLogger(__name__)


class SpecParser:
    """Parse agent specifications from Mother's output."""

    JSON_START_MARKER = "AGENT_SPEC_JSON_START"
    JSON_END_MARKER = "AGENT_SPEC_JSON_END"
    TEXT_START_MARKER = "AGENT_SPEC_START"
    TEXT_END_MARKER = "AGENT_SPEC_END"

    def parse_spec_file(self, spec_file: Path) -> list[AgentSpec]:
        """
        Parse agent specification from Mother's output file.

        Tries JSON format first (preferred), falls back to legacy text format.

        Args:
            spec_file: Path to specification file

        Returns:
            List of parsed agent specifications

        Raises:
            ValueError: If no valid specification found
        """
        content = spec_file.read_text()

        agents = self._try_parse_json(content)
        if agents:
            logger.info(f"Parsed {len(agents)} agents from JSON spec")
            return agents

        agents = self._try_parse_legacy(content)
        if agents:
            logger.info(f"Parsed {len(agents)} agents from legacy text spec")
            return agents

        raise ValueError("No valid agent specification found in file")

    def _try_parse_json(self, content: str) -> Optional[list[AgentSpec]]:
        """
        Try to parse JSON specification block.

        Looks for content between AGENT_SPEC_JSON_START and AGENT_SPEC_JSON_END.
        Uses jq for robust JSON parsing.

        Args:
            content: File content

        Returns:
            List of agents or None if parsing failed
        """
        matches = list(re.finditer(
            rf"{self.JSON_START_MARKER}(.*?){self.JSON_END_MARKER}",
            content,
            re.DOTALL | re.IGNORECASE,
        ))

        if not matches:
            return None

        json_match = matches[-1]
        json_block = json_match.group(1).strip()
        
        lines = json_block.split("\n")
        filtered_lines = []
        for line in lines:
            line = line.strip()
            if line and not line.startswith("⏺") and not line.startswith(">"):
                if line.startswith("{"):
                    filtered_lines.append(line)
                elif filtered_lines:
                    filtered_lines.append(line)
        
        json_block = " ".join(filtered_lines)

        json_block = self._sanitize_json_block(json_block)

        try:
            result = subprocess.run(
                ["jq", "-r", ".agents"],
                input=json_block,
                capture_output=True,
                text=True,
                check=True,
            )

            agents_data = json.loads(result.stdout)

            if not isinstance(agents_data, list):
                logger.warning("JSON spec .agents is not a list")
                return None

            agents = []
            for agent_data in agents_data:
                try:
                    agent = AgentSpec(
                        window=int(agent_data["window"]),
                        name=agent_data["name"],
                        role=agent_data["role"],
                        depends_on=agent_data.get("depends_on", []),
                        notifies=agent_data.get("notifies", []),
                        wait_for=agent_data.get("wait_for", []),
                    )
                    agents.append(agent)
                except (KeyError, ValueError) as e:
                    logger.warning(f"Invalid agent data: {e}")
                    continue

            return agents if agents else None

        except (subprocess.CalledProcessError, json.JSONDecodeError) as e:
            logger.warning(f"JSON parsing failed: {e}")
            return None

    def _sanitize_json_block(self, json_block: str) -> str:
        """
        Sanitize JSON block by removing common artifacts.

        - Strip markdown code fences (```)
        - Remove REPL prompts (claude>, cursh>, etc.)
        - Remove repeated prompts

        Args:
            json_block: Raw JSON block

        Returns:
            Sanitized JSON
        """
        lines = json_block.split("\n")
        cleaned_lines = []

        for line in lines:
            line = re.sub(r"^```.*$", "", line)

            line = re.sub(r"^(\s*)(([A-Za-z_][A-Za-z0-9_]*\s+)*[A-Za-z_][A-Za-z0-9_]*>\s*)", r"\1", line)

            if line.strip():
                cleaned_lines.append(line)

        return "\n".join(cleaned_lines)

    def _try_parse_legacy(self, content: str) -> Optional[list[AgentSpec]]:
        """
        Try to parse legacy text specification format.

        Format:
            AGENT_SPEC_START
            AGENT:3:frontend_dev:Build React components
            DEPENDS_ON:none
            NOTIFIES:validator
            WAIT_FOR:none
            ...
            AGENT_SPEC_END

        Args:
            content: File content

        Returns:
            List of agents or None if parsing failed
        """
        text_match = re.search(
            rf"{self.TEXT_START_MARKER}\s*\n(.*?)\n\s*{self.TEXT_END_MARKER}",
            content,
            re.DOTALL | re.IGNORECASE,
        )

        if not text_match:
            return None

        spec_block = text_match.group(1)
        agents = []
        current_agent: Optional[dict[str, any]] = None

        for line in spec_block.split("\n"):
            line = line.strip()
            if not line:
                continue

            if line.upper().startswith("AGENT:"):
                if current_agent:
                    try:
                        agents.append(self._build_agent_from_dict(current_agent))
                    except ValueError as e:
                        logger.warning(f"Invalid agent: {e}")

                parts = line.split(":", 3)
                if len(parts) >= 4:
                    current_agent = {
                        "window": int(parts[1]),
                        "name": parts[2].strip(),
                        "role": parts[3].strip(),
                        "depends_on": [],
                        "notifies": [],
                        "wait_for": [],
                    }

            elif current_agent:
                if line.upper().startswith("DEPENDS_ON:"):
                    value = line.split(":", 1)[1].strip()
                    if value.lower() != "none":
                        current_agent["depends_on"] = [
                            s.strip() for s in value.split(",")
                        ]

                elif line.upper().startswith("NOTIFIES:"):
                    value = line.split(":", 1)[1].strip()
                    if value.lower() != "none":
                        current_agent["notifies"] = [
                            s.strip() for s in value.split(",")
                        ]

                elif line.upper().startswith("WAIT_FOR:"):
                    value = line.split(":", 1)[1].strip()
                    if value.lower() != "none":
                        current_agent["wait_for"] = [
                            s.strip() for s in value.split(",")
                        ]

        if current_agent:
            try:
                agents.append(self._build_agent_from_dict(current_agent))
            except ValueError as e:
                logger.warning(f"Invalid agent: {e}")

        return agents if agents else None

    def _build_agent_from_dict(self, data: dict[str, any]) -> AgentSpec:
        """Build AgentSpec from dictionary."""
        return AgentSpec(
            window=data["window"],
            name=data["name"],
            role=data["role"],
            depends_on=data.get("depends_on", []),
            notifies=data.get("notifies", []),
            wait_for=data.get("wait_for", []),
        )
