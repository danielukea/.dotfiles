#! /usr/bin/env bash

dependencies=(make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev python-openssl git neovim stow zsh pipenv)

for d in $dependencies; do
  if sudo dpkg-query -s $d >/dev/null; then
      echo "$d has already been installed."
  else
      sudo apt install $d && "$d is installed."
  fi
done

