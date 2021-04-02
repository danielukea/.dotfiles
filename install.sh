#! /usr/bin/env bash

dependencies=("stow" "zsh" "oh-my-zsh" "nvim")

function install() {
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
