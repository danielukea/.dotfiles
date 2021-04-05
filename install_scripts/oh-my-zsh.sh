#! /usr/bin/env bash

if [[ -d ~/.oh-my-zsh ]]; then
    echo 'oh my zsh already installed. Check ~/.oh-my-zsh'
else
  echo "Installing oh-my-zsh"

  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && echo "oh-my-zsh has been installed"
fi
