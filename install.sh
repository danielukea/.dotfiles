#! /usr/bin/env bash

sudo apt update
sudo apt upgrade

for f in ./install_scripts/*; do
    echo "running install script for $f ..."
    bash "$f" || echo "$f failed to install."
    echo "install file: $f has been run"
done
echo "finished installing"
