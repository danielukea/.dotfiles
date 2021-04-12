#! /usr/bin/env bash

for d in * ; do
 if [ ! -d "$d" ]; then
     continue
 fi

 if [ "$d" == "install_scripts" ]; then
     continue
 fi

 if [ "$d" == "nvim" ]; then
     stow nvim -t ~/.config
     continue
 fi

 stow $d -v
done
