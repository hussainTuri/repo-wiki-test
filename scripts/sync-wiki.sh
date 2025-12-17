#!/usr/bin/env bash
set -e

REPO_NAME="messaging"
WIKI_REPO="https://github.com/${GITHUB_REPOSITORY}.wiki.git"

# Use GitHub token for authenticated wiki clone when available (GitHub Actions)
if [ -n "${GITHUB_TOKEN:-}" ]; then
  WIKI_REPO="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.wiki.git"
fi

# Resolve workspace path (GitHub Actions sets GITHUB_WORKSPACE)
WORKSPACE="${GITHUB_WORKSPACE:-$(pwd)}"

# Ensure we are not inheriting a stale git context (e.g. GIT_DIR from checkout)
unset GIT_DIR
unset GIT_WORK_TREE

rm -rf /tmp/wiki
mkdir -p /tmp/wiki

if git clone "$WIKI_REPO" /tmp/wiki; then
  cd /tmp/wiki
else
  echo "Wiki repo not found, initializing new wiki repo"
  cd /tmp/wiki
  git init
  git remote add origin "$WIKI_REPO"
fi

# Remove old content (except Home.md and git metadata)
find . -type f ! -name "Home.md" ! -path "./.git/*" -delete

# Copy docs to wiki from the checked-out repository
cp -R "${WORKSPACE}/docs/." .

# Use docs/README.md as the Wiki home page
cp "${WORKSPACE}/docs/README.md" Home.md

git config user.name "github-actions"
git config user.email "github-actions@github.com"

git add .
git commit -m "Sync wiki from docs folder" || exit 0
git push
