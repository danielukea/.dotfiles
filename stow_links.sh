#! /usr/bin/env bash

for d in * ; do
 if [ "$d" == "install_scripts" ]; then
     continue
 fi

 if [ -d "$d" ]; then
  stow $d -v
 fi
done
