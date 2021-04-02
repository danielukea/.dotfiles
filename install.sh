#! /usr/bin/env bash

dependencies=("stow" "zsh" "oh-my-zsh" "nvim" "brew" "misc_essentials")

function install() {
 if which $1; then
     echo 'already installed'
     return 0
 fi

 case $1 in
 stow)
   apt-get install stow
 ;;
 zsh)
   apt-get install zsh
 ;;
 oh-my-zsh)
   sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
 ;;
 nvim)
  apt-get install neovim
  mkdir ~/.config/nvim/ -p
  touch ~/.config/nvim/init.vim
  echo "set runtimepath+=~/.vim,~/.vim/after
        set packpath+=~/.vim
        source ~/.vimrc" >> ~/.config/nvim/init.vim
 ;;
 brew)
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # profile only loads on login
  echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.profile
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
 ;;
 scmpuff)
  brew install scmpuff
 ;;
 asdf)
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.8.0
 ;;
 misc_essentials)
  apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev python-openssl git
 ;;
 esac
}

if [ $# -eq 0 ];then
  for t in ${dependencies[@]}; do

    dpkg-query --show $t
    PACKAGE_RETURN_CODE=$?

    if [ "$PACKAGE_RETURN_CODE" = "0" ]; then
      echo "dependency satisfied $t"
      continue
    else
      echo "must download package $t"
      install $t
    fi
  done
else
 for var in "$@"; do
   install $var
 done
fi
