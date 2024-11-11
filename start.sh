#!/usr/bin/env bash

set -euo pipefail
shopt -s inherit_errexit

sudo apt update
sudo apt install git

test -d "$HOME"/.config/provision-conf || \
  git clone \
    git@github.com:LiamGoodacre/provision-conf.git \
    "$HOME"/.config/provision-conf

cd "$HOME"/.config/provision-conf
git pull --rebase --autostash
exec ./provision.sh
