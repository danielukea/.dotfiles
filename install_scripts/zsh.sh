#! /usr/bin/env bash

if which zsh >/dev/null; then
    echo "zsh is already installed"
else
    apt-get install zsh && echo "zsh was successfully insalled."
fi
