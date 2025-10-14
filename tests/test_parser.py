"""Tests for agent specification parser."""

import json
from pathlib import Path

import pytest

from taco.models import AgentSpec
from taco.parser import SpecParser


@pytest.fixture
def parser():
    """Create parser instance."""
    return SpecParser()


@pytest.fixture
def sample_json_spec(tmp_path):
    """Create sample JSON specification file."""
    content = """
Some preamble text...

AGENT_SPEC_JSON_START
{
  "agents": [
    {
      "window": 3,
      "name": "frontend_dev",
      "role": "Build React components and UI",
      "depends_on": [],
      "notifies": ["validator"],
      "wait_for": []
    },
    {
      "window": 4,
      "name": "backend_dev",
      "role": "Create API endpoints",
      "depends_on": [],
      "notifies": ["validator"],
      "wait_for": []
    },
    {
      "window": 5,
      "name": "validator",
      "role": "Code quality validation",
      "depends_on": ["frontend_dev", "backend_dev"],
      "notifies": ["tester"],
      "wait_for": []
    },
    {
      "window": 6,
      "name": "tester",
      "role": "Run all tests",
      "depends_on": ["validator"],
      "notifies": [],
      "wait_for": ["validator"]
    }
  ]
}
AGENT_SPEC_JSON_END

Some trailing text...
"""
    spec_file = tmp_path / "spec.txt"
    spec_file.write_text(content)
    return spec_file


@pytest.fixture
def sample_legacy_spec(tmp_path):
    """Create sample legacy text specification file."""
    content = """
AGENT_SPEC_START
AGENT:3:frontend_dev:Build React components and UI
DEPENDS_ON:none
NOTIFIES:validator
WAIT_FOR:none

AGENT:4:backend_dev:Create API endpoints
DEPENDS_ON:none
NOTIFIES:validator
WAIT_FOR:none

AGENT:5:validator:Code quality validation
DEPENDS_ON:frontend_dev,backend_dev
NOTIFIES:tester
WAIT_FOR:none

AGENT:6:tester:Run all tests
DEPENDS_ON:validator
NOTIFIES:none
WAIT_FOR:validator
AGENT_SPEC_END
"""
    spec_file = tmp_path / "spec.txt"
    spec_file.write_text(content)
    return spec_file


def test_parse_json_spec(parser, sample_json_spec):
    """Test parsing JSON specification."""
    agents = parser.parse_spec_file(sample_json_spec)

    assert len(agents) == 4

    assert agents[0].window == 3
    assert agents[0].name == "frontend_dev"
    assert agents[0].role == "Build React components and UI"
    assert agents[0].depends_on == []
    assert agents[0].notifies == ["validator"]
    assert agents[0].wait_for == []

    assert agents[2].window == 5
    assert agents[2].name == "validator"
    assert agents[2].depends_on == ["frontend_dev", "backend_dev"]
    assert agents[2].notifies == ["tester"]


def test_parse_legacy_spec(parser, sample_legacy_spec):
    """Test parsing legacy text specification."""
    agents = parser.parse_spec_file(sample_legacy_spec)

    assert len(agents) == 4

    assert agents[0].window == 3
    assert agents[0].name == "frontend_dev"
    assert agents[0].role == "Build React components and UI"

    assert agents[3].window == 6
    assert agents[3].name == "tester"
    assert agents[3].depends_on == ["validator"]
    assert agents[3].wait_for == ["validator"]


def test_sanitize_json_block(parser):
    """Test JSON block sanitization."""
    dirty_json = """```json
claude> {
claude>   "agents": [
cursh cursh> {"window": 3}
claude>   ]
claude> }
```"""

    clean = parser._sanitize_json_block(dirty_json)

    assert "```" not in clean
    assert "claude>" not in clean
    assert "cursh" not in clean
    assert '{"window": 3}' in clean


def test_invalid_agent_window():
    """Test that invalid window numbers are rejected."""
    with pytest.raises(ValueError, match="window must be >= 3"):
        AgentSpec(window=1, name="test", role="test role")


def test_empty_agent_name():
    """Test that empty agent names are rejected."""
    with pytest.raises(ValueError, match="name cannot be empty"):
        AgentSpec(window=3, name="", role="test role")


def test_no_spec_found(parser, tmp_path):
    """Test handling of file with no specification."""
    spec_file = tmp_path / "empty.txt"
    spec_file.write_text("No spec here")

    with pytest.raises(ValueError, match="No valid agent specification found"):
        parser.parse_spec_file(spec_file)
