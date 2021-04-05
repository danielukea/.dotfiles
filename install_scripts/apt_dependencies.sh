#! /usr/bin/env bash
source ./dependencies.sh

for d in "${APT[@]}"; do
  if sudo dpkg-query -s $d >/dev/null; then
      echo "$d has already been installed."
  else
      sudo apt install $d && "$d is installed."
  fi
done

