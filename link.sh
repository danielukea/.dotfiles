#!/usr/bin/env zsh

# Script to symlink dotfiles to home directory using the stow cask

# Install stow if list does not resolve to a success code (meaning it's not installed)
# This ensures stow is installed on first time runs on the machine
brew list stow &>/dev/null || brew install stow

STOW_FOLDERS="nvim,tmux,kitty"
DOT_FILES="$HOME/.dotfiles"

pushd $DOT_FILES
for folder in $(echo $STOW_FOLDERS | sed "s/,/ /g")
do
  echo "Symlinking $folder dotfiles to home directory"
  stow -D $folder
  stow $folder
done
popd

echo "Done - dotfiles linked"
