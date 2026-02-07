#!/usr/bin/env bash

set -e

DOTFILES_DIR="$HOME/.dotfiles"
LOG_PREFIX="[dotfiles-sync]"

cd "$DOTFILES_DIR"

echo "$LOG_PREFIX $(date): Checking for updates..."

git fetch origin main

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" != "$REMOTE" ]; then
    echo "$LOG_PREFIX Changes detected, pulling..."
    git pull --ff-only origin main
    echo "$LOG_PREFIX Re-linking dotfiles..."
    ./link.sh link
    echo "$LOG_PREFIX Sync complete!"
else
    echo "$LOG_PREFIX Already up to date."
fi
