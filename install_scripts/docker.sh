#! /usr/bin/env bash

################################################
# Install through apt instructions
################################################
# Dependencies are installed via apt_dependencies
# allow apt to use repo over HTTPS
# sudo apt-get update
# sudo apt-get install \
#    apt-transport-https \
#    ca-certificates \
#    curl \
#    gnupg \
#    lsb-release

# add dockers official GPG key
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# set up stable repository
# echo \
#   "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
#   $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
#
# sudo apt update
# sudo apt install docker-ce docker-ce-cli containerd.io
