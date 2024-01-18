#!/usr/bin/env zsh

STOW_FOLDERS="nvim,tmux"
DOT_FILES=$HOME/.dotfiles

pushd $DOT_FILES
for folder in $(echo $STOW_FOLDERS  | sed "s/,/ /g"); do
  echo "Removing folder symlink for $folder dotfiles"
  stow -D $folder
done
popd
