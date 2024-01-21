#!/usr/bin/env zsh

echo "Installing the .dotfiles"
echo "STEP 1: cleanup existing stow links"
./link.sh unlink
echo "STEP 2: link existing stow links"
./link.sh link
pushd $HOME

echo "STEP 3: install all brew files"
brew bundle install

echo "STEP 4: install asdf plugin manager"
asdf plugin add asdf-plugin-manager https://github.com/asdf-community/asdf-plugin-manager.git
asdf install asdf-plugin-manager latest

echo "STEP 5: install all asdf plugins"
asdf-plugin-manager add-all

echo "STEP 6: install all asdf dependencies"
asdf install

popd
