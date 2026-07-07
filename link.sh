#!/usr/bin/env bash

set -e  # Exit on any error

if [ "$#" -eq 0 ] || [ "$1" = "--help" ]; then
  echo "$0: Manage dotfiles by creating or removing symbolic links."
  echo
  echo "Usage:"
  echo "  $0 [ACTION]"
  echo
  echo "Actions:"
  echo "  - link    : Symlink dotfiles from folders within ~/.dotfiles to the home directory."
  echo "              Example: $0 link"
  echo
  echo "  - unlink  : Remove symlinks of dotfiles from the home directory."
  echo "              Example: $0 unlink"
  echo
  echo "Dependencies:"
  echo "  - Homebrew (macOS) or apt (Ubuntu) for installing stow"
  echo
  echo "Note:"
  echo "  Ensure that your dotfiles are organized within the ~/.dotfiles directory, with each configuration in its own subdirectory."
  echo
  echo "Author:"
  echo "  Luke Danielson"
  exit 0
fi

# Install stow if not present (cross-platform)
if ! command -v stow &>/dev/null; then
  if [[ "$(uname)" == "Darwin" ]]; then
    brew install stow
  else
    sudo apt-get update && sudo apt-get install -y stow
  fi
fi


DOT_FILES="$HOME/.dotfiles"

link_dotfiles() {
  pushd $DOT_FILES
  for folder in */; do
    folder=${folder%/}  # Remove trailing slash
    echo "Symlinking $folder dotfiles to home directory"
    stow $folder -v --adopt
  done
  popd
  bridge_claude_skills
  echo "✅ Dotfiles linked successfully!"
}

unlink_dotfiles() {
  pushd $DOT_FILES
  for folder in */; do
    folder=${folder%/}  # Remove trailing slash
    echo "Unlinking $folder dotfiles from home directory"
    stow -D $folder -v
  done
  popd
  unbridge_claude_skills
  echo "✅ Dotfiles unlinked successfully!"
}

# Claude Code only discovers skills under ~/.claude/skills/, but dotfiles-canonical
# skills live under ~/.agents/skills/ (agent-agnostic, shared with Codex/Gemini CLI).
# Bridge every ~/.agents/skills/* entry into ~/.claude/skills/ so newly added skills
# are always discoverable without a separate manual symlink step.
bridge_claude_skills() {
  local agents_skills="$HOME/.agents/skills"
  local claude_skills="$HOME/.claude/skills"
  [ -d "$agents_skills" ] || return 0
  mkdir -p "$claude_skills"
  for skill_dir in "$agents_skills"/*/; do
    [ -d "$skill_dir" ] || continue
    local name
    name=$(basename "$skill_dir")
    local link="$claude_skills/$name"
    if [ ! -e "$link" ]; then
      ln -s "../../.agents/skills/$name" "$link"
      echo "Bridged skill: ~/.claude/skills/$name -> ~/.agents/skills/$name"
    fi
  done
}

# Remove only the bridge symlinks link.sh created (points into ../../.agents/skills/),
# leaving any unrelated ~/.claude/skills/ entries (e.g. plain marketplace installs) alone.
unbridge_claude_skills() {
  local claude_skills="$HOME/.claude/skills"
  [ -d "$claude_skills" ] || return 0
  for link in "$claude_skills"/*; do
    [ -L "$link" ] || continue
    case "$(readlink "$link")" in
      ../../.agents/skills/*) rm "$link" ;;
    esac
  done
}

case "$1" in
  link)
    link_dotfiles
    ;;
  unlink)
    unlink_dotfiles
    ;;
  *)
    echo "Usage: $0 {link|unlink}"
    exit 1
    ;;
esac


