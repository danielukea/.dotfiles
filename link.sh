#!/usr/bin/env zsh

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
  echo "  - Homebrew (for installing stow)"
  echo
  echo "Note:"
  echo "  Ensure that your dotfiles are organized within the ~/.dotfiles directory, with each configuration in its own subdirectory."
  echo
  echo "Author:"
  echo "  Your Name"
  exit 0
fi

brew list stow &>/dev/null || brew install stow


DOT_FILES="$HOME/.dotfiles"

link_dotfiles() {
  pushd $DOT_FILES
  for folder in */; do
    folder=${folder%/}  # Remove trailing slash
    echo "Symlinking $folder dotfiles to home directory"
    stow $folder -v
  done
  popd
  echo "Done - dotfiles linked"
}

unlink_dotfiles() {
  pushd $DOT_FILES
  for folder in */; do
    folder=${folder%/}  # Remove trailing slash
    echo "Unlinking $folder dotfiles from home directory"
    stow -D $folder -v
  done
  popd
  echo "Done - dotfiles unlinked"
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


