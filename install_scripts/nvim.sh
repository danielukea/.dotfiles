#! /usr/bin/env bash

if which nvim >/dev/null; then
    echo "nvim is already installed."
else
  echo "Installing neovim..."
  apt-get install neovim

  echo "creating ~/.config/nvim/init.vim file..."
  mkdir ~/.config/nvim/ -p
  touch ~/.config/nvim/init.vim

  echo "pointing init.vim file to ~/.vimrc configuration..."
  echo "set runtimepath+=~/.vim,~/.vim/after
          set packpath+=~/.vim
          source ~/.vimrc" >> ~/.config/nvim/init.vim

  echo "nvim has been installed"
fi

