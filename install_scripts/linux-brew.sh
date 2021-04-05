#! /usr/bin/env bash

# >/dev/null silences the output
if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
    echo "brew is already installed check: /home/linuxbrew/.linuxbrew"
else
  echo "installing brew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # profile only loads on login
  echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.profile
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  echo "Need to logout and log back in again to activate. Added dependency to .profile"
  echo "Brew is now installed"
fi

