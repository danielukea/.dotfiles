#! /usr/bin/env bash

# installs all of the bash dependencies
dependencies=("stow" "zsh" "oh-my-zsh")

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
 esac
}

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
