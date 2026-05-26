#!/usr/bin/env bash
# 팀 GitHub 저장소로 main + app 브랜치 push
# 사용: ./scripts/migrate_to_team_github.sh git@github.com:YOUR_ORG/celebfit.git
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <team-repo-git-url>"
  echo "Example: $0 git@github.com:celebfit-team/celebfit.git"
  exit 1
fi

TEAM_URL="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Remote: $TEAM_URL"
git remote remove team 2>/dev/null || true
git remote add team "$TEAM_URL"

echo "==> Push main ..."
git push team main:main

echo "==> Push app ..."
git push team app:app

echo "==> Set origin to team repo (optional)"
git remote set-url origin "$TEAM_URL"

echo ""
echo "Done."
echo "  main: $TEAM_URL (branch main)"
echo "  app:  $TEAM_URL (branch app)"
echo ""
echo "GitHub → Settings → Collaborators 에 팀원 초대"
echo "Docker Hub Secrets (Actions): DOCKERHUB_USERNAME, DOCKERHUB_TOKEN"
