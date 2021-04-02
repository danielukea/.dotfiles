#! /usr/bin/env bash

for d in * ; do
 if [ -d "$d" ]; then
  stow $d -v
 fi 
done
