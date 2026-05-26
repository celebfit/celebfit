#!/usr/bin/env bash
# main 브랜치 ML 변경을 app 브랜치에 merge (로컬)
# Usage: ./scripts/sync_main_to_app.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

git fetch origin main app

current="$(git branch --show-current)"
if [[ "$current" != "app" ]]; then
  git checkout app
fi

echo "Merging origin/main into app..."
if git merge origin/main --no-edit; then
  echo "Merge OK. Push with: git push origin app"
else
  echo "Merge conflict. Resolve files, then: git add -A && git commit && git push origin app" >&2
  exit 1
fi
