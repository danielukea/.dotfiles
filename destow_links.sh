#! /usr/bin/env bash

for d in * ; do
 if [ -d "$d" ]; then
  stow -D -v $d
 fi
done
