#! /usr/bin/env bash

source ./dependencies.sh

if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
    echo "installing brew dependencies"
    for d in "${BREW[@]}"; do
        if brew list $d >/dev/null;then
            echo "$d already installed."
        else
            brew install $d
        fi
    done
else
    echo "Brew needs to be installed to install these dependencies"
    read -r -p "Do you want to install brew? [Y/n] " input
    case $input in
        [yY][eE][sS]|[yY])
     echo "Yes"
     echo "installing brew..."
     sh ./install_scripts/linux-brew.sh

     ;;
        [nN][oO]|[nN])
     echo "No"
     echo "Not installing any brew dependencies"
           ;;
        *)
     echo "Invalid input..."
     exit 1
     ;;
    esac
fi
