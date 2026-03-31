#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bootstrap_repo.sh --path PATH [options]
  bootstrap_repo.sh --interactive [--path PATH]

Options:
  --path PATH           Target project directory
  --name NAME           GitHub repo name (default: basename of path)
  --description DESC    Short repo description
  --stack STACK         generic | python | node | hybrid | android (default: generic)
  --visibility VIS      public | private (default: public)
  --interactive         Prompt for missing values and suggest defaults
  --create-github       Create/push the repo on GitHub via gh
  --skip-commit         Do not create an initial commit
  --help                Show this message

Examples:
  ./scripts/bootstrap_repo.sh --path /Users/giminu0930/Desktop/mail-mcp-agent --stack node --create-github --description "Local IMAP mail agent with MCP tools"
  ./scripts/bootstrap_repo.sh --path /Users/giminu0930/Desktop/01_Projects/openai-realtime-transcribe --stack python
  ./scripts/bootstrap_repo.sh --interactive --path /Users/giminu0930/Desktop/mail-mcp-agent --create-github
EOF
}

require_value() {
  local value="$1"
  local flag="$2"
  if [[ -z "$value" ]]; then
    echo "Missing value for $flag" >&2
    exit 1
  fi
}

write_file_if_missing() {
  local path="$1"
  local content="$2"
  if [[ ! -f "$path" ]]; then
    printf '%s' "$content" > "$path"
    echo "Created $(basename "$path")"
  fi
}

build_gitignore() {
  local stack="$1"
  case "$stack" in
    python)
      cat <<'EOF'
.DS_Store
.env
.venv/
venv/
__pycache__/
*.pyc
.pytest_cache/
dist/
build/
outputs/
coverage/
EOF
      ;;
    node)
      cat <<'EOF'
.DS_Store
.env
node_modules/
dist/
build/
.next/
coverage/
*.log
outputs/
EOF
      ;;
    hybrid)
      cat <<'EOF'
.DS_Store
.env
.venv/
venv/
__pycache__/
*.pyc
.pytest_cache/
node_modules/
dist/
build/
.next/
coverage/
*.log
outputs/
EOF
      ;;
    android)
      cat <<'EOF'
.DS_Store
.env
.gradle/
build/
*/build/
.idea/
local.properties
captures/
outputs/
EOF
      ;;
    generic|*)
      cat <<'EOF'
.DS_Store
.env
.venv/
venv/
__pycache__/
*.pyc
.pytest_cache/
node_modules/
dist/
build/
coverage/
*.log
outputs/
EOF
      ;;
  esac
}

build_readme() {
  local name="$1"
  local description="$2"
  local stack="$3"
  local quickstart=""

  case "$stack" in
    python)
      quickstart='```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```'
      ;;
    node)
      quickstart='```bash
npm install
npm run dev
```'
      ;;
    hybrid)
      quickstart='```bash
# install frontend/backend dependencies as needed
```'
      ;;
    android)
      quickstart='```bash
# open the project in Android Studio
```'
      ;;
    *)
      quickstart='```bash
# add setup steps here
```'
      ;;
  esac

  cat <<EOF
# $name

${description:-Short project summary goes here.}

## What It Does

- describe the problem this project solves
- describe the main workflow or output
- describe the intended users or use case

## Quick Start

$quickstart

## Notes

- replace this README with project-specific setup and usage details
EOF
}

generate_env_example() {
  local env_path="$1"
  local example_path="$2"

  if [[ ! -f "$env_path" || -f "$example_path" ]]; then
    return
  fi

  python3 - "$env_path" "$example_path" <<'PY'
import re
import sys
from pathlib import Path

env_path = Path(sys.argv[1])
example_path = Path(sys.argv[2])
lines = env_path.read_text().splitlines()
keys = []
seen = set()

for line in lines:
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        continue
    stripped = re.sub(r"^export\s+", "", stripped)
    if "=" not in stripped:
        continue
    key, _ = stripped.split("=", 1)
    key = key.strip()
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
        continue
    if key in seen:
        continue
    seen.add(key)
    keys.append(f"{key}=")

example_path.write_text("\n".join(keys) + ("\n" if keys else ""))
PY

  if [[ -f "$example_path" ]]; then
    echo "Generated $(basename "$example_path") from .env keys"
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

infer_stack() {
  local project_path="$1"
  local has_python="false"
  local has_node="false"
  local has_android="false"

  if [[ -f "$project_path/pyproject.toml" || -f "$project_path/requirements.txt" || -n "$(find "$project_path" -maxdepth 2 -type f -name '*.py' -print -quit 2>/dev/null)" ]]; then
    has_python="true"
  fi

  if [[ -f "$project_path/package.json" || -f "$project_path/package-lock.json" || -f "$project_path/pnpm-lock.yaml" || -f "$project_path/yarn.lock" ]]; then
    has_node="true"
  fi

  if [[ -f "$project_path/build.gradle" || -f "$project_path/build.gradle.kts" || -f "$project_path/settings.gradle" || -f "$project_path/settings.gradle.kts" || -f "$project_path/gradlew" || -d "$project_path/android" ]]; then
    has_android="true"
  fi

  if [[ "$has_python" == "true" && "$has_node" == "true" ]]; then
    printf '%s' "hybrid"
  elif [[ "$has_android" == "true" ]]; then
    printf '%s' "android"
  elif [[ "$has_python" == "true" ]]; then
    printf '%s' "python"
  elif [[ "$has_node" == "true" ]]; then
    printf '%s' "node"
  else
    printf '%s' "generic"
  fi
}

infer_description() {
  local project_path="$1"

  python3 - "$project_path" <<'PY'
import sys
from pathlib import Path

project_path = Path(sys.argv[1])
readme_candidates = ["README.md", "README.MD", "README.txt", "README"]

for candidate in readme_candidates:
    path = project_path / candidate
    if not path.exists():
        continue
    for raw_line in path.read_text(errors="ignore").splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("#"):
            continue
        if line.startswith("```"):
            continue
        if line.startswith("- ") or line.startswith("* "):
            continue
        print(line)
        raise SystemExit(0)

print("")
PY
}

prompt_with_default() {
  local prompt_text="$1"
  local default_value="$2"
  local result=""

  if [[ -n "$default_value" ]]; then
    read -r -p "$prompt_text [$default_value]: " result
    result="$(trim "$result")"
    if [[ -z "$result" ]]; then
      result="$default_value"
    fi
  else
    read -r -p "$prompt_text: " result
    result="$(trim "$result")"
  fi

  printf '%s' "$result"
}

prompt_yes_no() {
  local prompt_text="$1"
  local default_value="$2"
  local result=""

  read -r -p "$prompt_text [$default_value]: " result
  result="$(trim "$result")"
  if [[ -z "$result" ]]; then
    result="$default_value"
  fi
  result="$(printf '%s' "$result" | tr '[:upper:]' '[:lower:]')"

  case "$result" in
    y|yes)
      printf '%s' "true"
      ;;
    n|no)
      printf '%s' "false"
      ;;
    *)
      printf '%s' "false"
      ;;
  esac
}

PATH_ARG=""
NAME_ARG=""
DESCRIPTION_ARG=""
STACK_ARG="generic"
VISIBILITY_ARG="public"
INTERACTIVE_MODE="false"
CREATE_GITHUB="false"
SKIP_COMMIT="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      PATH_ARG="${2:-}"
      require_value "$PATH_ARG" "--path"
      shift 2
      ;;
    --name)
      NAME_ARG="${2:-}"
      require_value "$NAME_ARG" "--name"
      shift 2
      ;;
    --description)
      DESCRIPTION_ARG="${2:-}"
      require_value "$DESCRIPTION_ARG" "--description"
      shift 2
      ;;
    --stack)
      STACK_ARG="${2:-}"
      require_value "$STACK_ARG" "--stack"
      shift 2
      ;;
    --visibility)
      VISIBILITY_ARG="${2:-}"
      require_value "$VISIBILITY_ARG" "--visibility"
      shift 2
      ;;
    --interactive)
      INTERACTIVE_MODE="true"
      shift
      ;;
    --create-github)
      CREATE_GITHUB="true"
      shift
      ;;
    --skip-commit)
      SKIP_COMMIT="true"
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$INTERACTIVE_MODE" == "true" && -z "$PATH_ARG" ]]; then
  PATH_ARG="$(prompt_with_default "Project folder path" "$PWD")"
fi

if [[ -z "$PATH_ARG" ]]; then
  usage
  exit 1
fi

PROJECT_PATH="$(cd "$(dirname "$PATH_ARG")" && pwd)/$(basename "$PATH_ARG")"

mkdir -p "$PROJECT_PATH"

INFERRED_STACK="$(infer_stack "$PROJECT_PATH")"
INFERRED_DESCRIPTION="$(infer_description "$PROJECT_PATH")"
INTERACTIVE_STACK_DEFAULT="$INFERRED_STACK"
INTERACTIVE_CREATE_DEFAULT="N"

if [[ "$STACK_ARG" != "generic" ]]; then
  INTERACTIVE_STACK_DEFAULT="$STACK_ARG"
fi

if [[ "$CREATE_GITHUB" == "true" ]]; then
  INTERACTIVE_CREATE_DEFAULT="Y"
fi

if [[ "$INTERACTIVE_MODE" == "true" ]]; then
  NAME_ARG="$(prompt_with_default "Repository name" "${NAME_ARG:-$(basename "$PROJECT_PATH")}")"
  STACK_ARG="$(prompt_with_default "Stack" "$INTERACTIVE_STACK_DEFAULT")"
  DESCRIPTION_ARG="$(prompt_with_default "Short description" "${DESCRIPTION_ARG:-$INFERRED_DESCRIPTION}")"
  VISIBILITY_ARG="$(prompt_with_default "Visibility (public/private)" "$VISIBILITY_ARG")"
  CREATE_GITHUB="$(prompt_yes_no "Create and push GitHub repo now?" "$INTERACTIVE_CREATE_DEFAULT")"
else
  if [[ "$STACK_ARG" == "generic" && "$INFERRED_STACK" != "generic" ]]; then
    STACK_ARG="$INFERRED_STACK"
  fi
fi

PROJECT_NAME="${NAME_ARG:-$(basename "$PROJECT_PATH")}"

if [[ "$VISIBILITY_ARG" != "public" && "$VISIBILITY_ARG" != "private" ]]; then
  echo "Visibility must be public or private" >&2
  exit 1
fi

write_file_if_missing "$PROJECT_PATH/.gitignore" "$(build_gitignore "$STACK_ARG")"
write_file_if_missing "$PROJECT_PATH/README.md" "$(build_readme "$PROJECT_NAME" "$DESCRIPTION_ARG" "$STACK_ARG")"
generate_env_example "$PROJECT_PATH/.env" "$PROJECT_PATH/.env.example"

if [[ ! -d "$PROJECT_PATH/.git" ]]; then
  if ! git -C "$PROJECT_PATH" init -b main >/dev/null 2>&1; then
    git -C "$PROJECT_PATH" init
    git -C "$PROJECT_PATH" branch -M main
  fi
  echo "Initialized Git repository"
fi

git -C "$PROJECT_PATH" add .

if [[ "$SKIP_COMMIT" != "true" ]]; then
  if [[ -n "$(git -C "$PROJECT_PATH" status --short)" ]]; then
    git -C "$PROJECT_PATH" commit -m "Initial project scaffold"
    echo "Created initial commit"
  else
    echo "No changes to commit"
  fi
fi

if [[ "$CREATE_GITHUB" == "true" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI is not installed. Install gh, then run GitHub creation manually." >&2
    exit 0
  fi

  if git -C "$PROJECT_PATH" remote get-url origin >/dev/null 2>&1; then
    echo "origin already exists"
    git -C "$PROJECT_PATH" push -u origin main
    exit 0
  fi

  if ! gh auth status >/dev/null 2>&1; then
    echo "gh authentication is not ready."
    echo "Run:"
    echo "  gh auth login -h github.com"
    echo "  gh repo create \"$PROJECT_NAME\" --$VISIBILITY_ARG --source \"$PROJECT_PATH\" --remote origin --push --description \"$DESCRIPTION_ARG\""
    exit 0
  fi

  if [[ -n "$DESCRIPTION_ARG" ]]; then
    gh repo create "$PROJECT_NAME" "--$VISIBILITY_ARG" --source "$PROJECT_PATH" --remote origin --push --description "$DESCRIPTION_ARG"
  else
    gh repo create "$PROJECT_NAME" "--$VISIBILITY_ARG" --source "$PROJECT_PATH" --remote origin --push
  fi

  echo "Created and pushed GitHub repository: $PROJECT_NAME"
fi
