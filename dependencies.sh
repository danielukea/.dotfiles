#! /usr/bin/env bash

# dependencies are arranged via install type
APT=(
 apt-transport-https # docker
 build-essential
 ca-certificates # docker
 curl # docker
 git
 gnupg # docker
 libbz2-dev
 libffi-dev
 liblzma-dev
 libncurses5-dev
 libncursesw5-dev
 libreadline-dev
 libsqlite3-dev
 libssl-dev
 llvm
 lsb-release # docker
 make
 neovim
 pipenv
 python-openssl
 stow
 tk-dev
 wget
 xz-utils
 zlib1g-dev
 zsh
)

BREW=(
 scmpuff
)

