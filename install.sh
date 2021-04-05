#! /usr/bin/env bash

for f in ./install_scripts/*; do
    echo "running install script for $f ..."
    bash "$f" || echo "$f failed to install."
    echo "$f installed"
done
echo "finished installing"
