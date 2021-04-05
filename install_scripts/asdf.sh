#! /usr/bin/env bash

if [[ -d ~/.asdf ]]; then
    echo "asdf has already been installed. Check your ~/.asdf directory"
else
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.8.0
fi
