#! /usr/bin/env bash

for d in * ; do
 if [ "$d" == "install_scripts" ]; then continue; fi

 if [ "$d" == "nvim" ]; then
     stow -D nvim -t ~/.config
     continue
 fi

 if [ -d "$d" ]; then
  stow -D -v $d
 fi
done
