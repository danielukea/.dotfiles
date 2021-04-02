#! /usr/bin/env bash

# installs all of the bash dependencies
dependencies=("stow" "zsh")

function install() {
 case $1 in
 stow)
   apt-get install stow
 ;;
 
 zsh)
   apt-get install zsh

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
    apt-get install $t
  fi
done


