#!/usr/bin/env bash
set -e

REPO_NAME="messaging"
WIKI_REPO="https://github.com/${GITHUB_REPOSITORY}.wiki.git"

rm -rf /tmp/wiki
git clone "$WIKI_REPO" /tmp/wiki

# Remove old content (except Home.md if you want)
find /tmp/wiki -type f ! -name "Home.md" -delete

# Copy docs to wiki
cp -R docs/* /tmp/wiki/

# Use docs/README.md as the Wiki home page
cp docs/README.md /tmp/wiki/Home.md

cd /tmp/wiki

git config user.name "github-actions"
git config user.email "github-actions@github.com"

git add .
git commit -m "Sync wiki from docs folder" || exit 0
git push
