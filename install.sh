#!/usr/bin/env zsh

set -e  # Exit on any error

echo "Installing the .dotfiles"
echo "STEP 1: cleanup existing stow links"
./link.sh unlink
echo "STEP 2: link existing stow links"
./link.sh link
pushd $HOME

echo "STEP 3: install all brew files"
brew bundle install

popd

echo "✅ Dotfiles installation complete!"
