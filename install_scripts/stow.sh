#! /usr/bin/env bash

if which stow >/dev/null; then
    echo "stow is already installed"
else
    "installing stow..."
     apt-get install stow && echo "Stow successfully installed"
fi
