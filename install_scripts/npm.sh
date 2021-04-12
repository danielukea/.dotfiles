#! /usr/bin/env bash
source ./dependencies.sh

for d in "${NPM[@]}"; do
  if npm list -g $d >/dev/null; then
      echo "$d has already been installed."
  else
      npm install -g $d && "$d is installed."
  fi
done
