#!/usr/bin/env bash
# Extract prompts from Python orchestrator to bash-compatible format

PYTHON_SRC="/Users/louisxsheid/dev/taco/src/taco/orchestrator.py"

# Extract Mother prompt (lines 621-951)
sed -n '621,951p' "$PYTHON_SRC" | \
  sed 's/^        return f"""//' | \
  sed 's/"""$//' | \
  sed 's/{user_request}/$USER_REQUEST/g' > mother-prompt.txt

# Extract Agent prompt (lines 953-1164)
sed -n '953,1164p' "$PYTHON_SRC" | \
  sed 's/^        return f"""//' | \
  sed 's/"""$//' | \
  sed 's/{agent.name}/$AGENT_NAME/g' | \
  sed 's/{agent.window}/$AGENT_WINDOW/g' | \
  sed 's/{agent.role}/$AGENT_ROLE/g' | \
  sed 's/{notifies}/$NOTIFIES/g' | \
  sed 's/{depends_on}/$DEPENDS_ON/g' > agent-prompt.txt

# Extract Coordination prompt (lines 1274-1785)
sed -n '1274,1785p' "$PYTHON_SRC" | \
  sed 's/^        coord_prompt = f"""//' | \
  sed 's/"""$//' | \
  sed 's/{agents_info}/$AGENTS_INFO/g' | \
  sed 's/{self.project_dir}/$PROJECT_DIR/g' > coordination-prompt.txt

echo "✅ Extracted 3 prompt templates"
