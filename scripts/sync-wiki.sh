#!/usr/bin/env bash
set -e

REPO_NAME="messaging"
WIKI_REPO="https://github.com/${GITHUB_REPOSITORY}.wiki.git"

# Use GitHub token for authenticated wiki clone when available (GitHub Actions)
if [ -n "${GITHUB_TOKEN:-}" ]; then
	WIKI_REPO="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.wiki.git"
fi

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

# Remove old content (except Home.md if you want)
find . -type f ! -name "Home.md" -delete

# Copy docs to wiki
cp -R ../docs/* .

# Use docs/README.md as the Wiki home page
cp ../docs/README.md Home.md

git config user.name "github-actions"
git config user.email "github-actions@github.com"

git add .
git commit -m "Sync wiki from docs folder" || exit 0
git push
