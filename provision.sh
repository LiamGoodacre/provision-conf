#!/usr/bin/env bash

set -euo pipefail
shopt -s inherit_errexit

# Utils {{{

confirm_with() {
  local response=n
  if which gum &>/dev/null; then
    if gum confirm "$1"; then
      echo -n y
    else
      echo -n n
    fi
  else
    read -p "$1 [y/N] " response
    if [[ "$response" == "y" ]]; then
      echo -n y
    else
      echo -n n
    fi
  fi
}

confirm_modify() {
  local path=$1
  if [[ -f "$path" ]]; then
    confirm_with "Modify $path?"
  else
    echo -n y
  fi
}

install_config() {
  local needle=$1; shift
  local path=$1; shift
  local target=$1; shift
  if ! grep -q -F "# $needle" "$path"; then
    if [[ "$(confirm_modify "$path")" == "y" ]]; then
      tee --append "$path" <<EOF
if [ -f "$target" ]; then . "$target"; fi # $needle
EOF
    fi
  fi
}

ensure_git() {
  local path=$1; shift
  local url=$1; shift
  test -d "$path" || git clone "$url" "$path"
}

replace_ln() {
  local path=$1; shift
  local target=$1; shift
  rm -f "$target"
  ln -s "$path" "$target"
}

# }}} Utils

# Lang {{{
if [[ "$LANG" != "en_GB.UTF-8" ]]; then
  if [[ "$(confirm_with 'Set locale to en_GB.UTF-8?')" == "y" ]]; then
    sudo locale-gen en_GB.UTF-8
    sudo update-locale LANG=en_GB.UTF-8
    sudo localectl set-locale LANG=en_GB.UTF-8
  fi
fi
# }}} Lang

# .bashrc {{{
install_config \
  'provision-conf/.bashrc' \
  "$HOME"/.bashrc \
  "$HOME"/.config/provision-conf/.bashrc
# }}} .bashrc

# .bash_aliases {{{
install_config \
  'provision-conf/.bash_aliases' \
  "$HOME"/.bash_aliases \
  "$HOME"/.config/provision-conf/.bash_aliases
# }}} .bash_aliases

gsettings set org.gnome.desktop.interface gtk-enable-primary-paste false

sudo apt update
sudo apt upgrade

# Basic tools {{{
sudo apt install \
  curl \
  git \
  xsel \
  xclip \
  ripgrep \
  build-essential \
  zlib1g-dev \
  fzf \
  tree \
  moreutils \
  gnome-tweaks \
  vlc
sudo snap install \
  htop
# }}} Basic tools

# Gum {{{
if [[ "$(confirm_with 'Install gum?')" == "y" ]]; then
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
  echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
  sudo apt update && sudo apt install gum
fi
# }}} Gum

# Disable middle mouse paste in Firefox {{{
if >/dev/null pgrep firefox; then
  >&2 echo "Firefox is running, skipping setting tweaks"
else
  ### whilst firefox is closed, and you've ran it at least once
  while read -r f; do
    if grep -q 'middlemouse.paste' "$f"; then continue; fi
    echo 'user_pref("middlemouse.paste", false);' >> "$f"
  done <<< $( find "$HOME"/snap/firefox/common/.mozilla/firefox/ -name prefs.js )
fi
# }}} Disable middle mouse paste in Firefox

ensure_git "$HOME"/.config/tokyonight-theme https://github.com/folke/tokyonight.nvim.git

# 1Password {{{
if [[ "$(confirm_with 'Install 1Password?')" == "y" ]]; then
  curl -L https://downloads.1password.com/linux/debian/amd64/stable/1password-latest.deb > ~/Downloads/1password-latest.deb
  sudo apt install ~/Downloads/1password-latest.deb
fi
# }}} 1Password

# Fingerprint reader {{{
if [[ "$(confirm_with 'Setup fingerprint reader & auth')" == "y" ]]; then
  sudo apt install libpam-fprintd fprintd
  fprintd-enroll # to enroll fingerprint
  sudo pam-auth-update # Then select "Fingerprint authentication"
fi
# }}} Fingerprint reader

# Ghostty {{{
if [[ "$(confirm_with 'Install Ghostty?')" == "y" ]]; then
  sudo snap install ghostty --classic
  ensure_git "$HOME"/.config/ghostty git@github.com:LiamGoodacre/ghostty-conf.git
  sudo tee /usr/bin/default-terminal <<"EOF"
#!/usr/bin/env bash
if [ $# -eq 0 ]; then
  exec ghostty -e tmux new -A -s default
else
  exec ghostty -e "$@"
fi
EOF
  sudo chmod +x /usr/bin/default-terminal
  sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/default-terminal 50
fi
# }}} Ghostty

# Configure git {{{
if [[ "$(confirm_with 'Configure git?')" == "y" ]]; then
  git config --global diff.color always
  git config --global diff.colorMoved zebra
  git config --global diff.colorMovedWS allow-indentation-change
  git config --global rebase.autostash true
  git config --global rebase.updateRefs true
fi
# }}} Configure git

# Hack Font {{{
if [[ "$(confirm_with 'Install Hack font?')" == "y" ]]; then
  sudo apt install fonts-hack-ttf
fi
# }}} Hack Font

# GHCup {{{
if [[ "$(confirm_with 'Install ghcup?')" == "y" ]]; then
  curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
fi
# }}} GHCup

# Tmux {{{
if [[ "$(confirm_with 'Install tmux')" == "y" ]]; then
  sudo apt install tmux
  ### Note: ensure bash >=5
  ensure_git "$HOME"/.config/tmux-conf git@github.com:LiamGoodacre/tmux-conf.git
  rm -f "$HOME"/.tmux.conf
  ln -s /home/liam/.config/tmux-conf/.tmux.conf "$HOME"/.tmux.conf
fi
# }}} Tmux

# NVM/Node {{{
### Needed for neovim Mason to install bzl & PureScript lsps
if [[ "$(confirm_with 'Install nvm & node?')" == "y" ]]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  (
    export NVM_DIR="$HOME/.config/nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install node latest
    nvm use node
  )
fi
# }}} NVM/Node

# Neovim {{{
if [[ "$(confirm_with 'Install neovim?')" == "y" ]]; then
  (
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT
    cd "$tmpdir" || exit 1
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage

    2>/dev/null sudo rm /usr/bin/nvim || true

    sudo install -m 755 nvim-linux-x86_64.appimage /usr/bin/nvim.appimage
    rm nvim-linux-x86_64.appimage

    cat <<'EOF' >>./nvim
#!/bin/bash
exec /usr/bin/nvim.appimage --appimage-extract-and-run "$@"
EOF
    sudo install -m 755 ./nvim /usr/bin/nvim
    rm ./nvim

    for e in editor ex vi view pico; do
      sudo update-alternatives --install `which $e` $e /usr/bin/nvim 50
    done
    test -d "$HOME"/.config/nvim || git clone git@github.com:LiamGoodacre/nvim-conf.git "$HOME"/.config/nvim
  )
fi
# }}} Neovim

# Jujitsu {{{
if [[ "$(confirm_with 'Install Jujitsu?')" == "y" ]]; then
  (
    tmpdir=$(mktemp -d)
    cd "$tmpdir" || exit 1
    curl -LO https://github.com/jj-vcs/jj/releases/download/v0.30.0/jj-v0.30.0-x86_64-unknown-linux-musl.tar.gz
    tar -xzf jj-v0.30.0-x86_64-unknown-linux-musl.tar.gz ./jj
    2>/dev/null sudo rm /usr/bin/jj || true
    sudo install -m 755 jj /usr/bin/jj
    rm jj
    rm jj-v0.30.0-x86_64-unknown-linux-musl.tar.gz
  )
fi
# }}} Jujitsu

# Tailscale {{{
if [[ "$(confirm_with 'Install/upgrade tailscale?')" == "y" ]]; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
# }}} Tailscale

# OBS Studio {{{
if [[ "$(confirm_with 'Install OBS Studio?')" == "y" ]]; then
  sudo add-apt-repository ppa:obsproject/obs-studio
  sudo apt install obs-studio
fi
# }}} OBS Studio

# Pip & venv {{{
if [[ "$(confirm_with 'Install pip & venv?')" == "y" ]]; then
  sudo apt install python3-pip python3-venv
fi
# }}} Pip & venv

# Godot {{{
if [[ "$(confirm_with 'Install Godot 4?')" == "y" ]]; then
  sudo snap install godot4
fi
# }}} Godot

# Bazelisk {{{
if [[ "$(confirm_with 'Install Bazel(isk)?')" == "y" ]]; then
  curl -L https://github.com/bazelbuild/bazelisk/releases/download/v1.26.0/bazelisk-amd64.deb > ~/Downloads/bazelisk-amd64.deb
  sudo apt install ~/Downloads/bazelisk-amd64.deb
  if [[ -f /usr/bin/bazel ]]; then
    sudo rm /usr/bin/bazel
  fi
  sudo ln -s /usr/bin/bazelisk /usr/bin/bazel

  # rules_haskell requires some extra packages
  sudo apt install build-essential libffi-dev libgmp-dev libtinfo6 libtinfo-dev python3 openjdk-11-jdk
fi
# }}} Bazelisk

# Docker {{{
if [[ "$(confirm_with 'Install Docker?')" == "y" ]]; then
  # Add Docker's official GPG key:
  sudo apt-get update
  sudo apt-get install ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources:
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  sudo groupadd docker
  sudo usermod -aG docker $USER
  newgrp docker
fi
# }}} Docker

# dotnet {{{
if [[ "$(confirm_with 'Install dotnet?')" == "y" ]]; then
  sudo add-apt-repository ppa:dotnet/backports
  sudo apt-get update
  sudo apt-get install -y dotnet-sdk-9.0 aspnetcore-runtime-9.0
fi
# }}} dotnet

### Set up ssh agent in 1Password
### Possibly add new ssh key to GitHub

# ### for ghc dev
# sudo apt-get install build-essential git autoconf python3 libgmp-dev libnuma-dev libncurses-dev
# cabal v2-install happy-2.0.2
# cabal v2-install alex

## hold until 52
# sudo apt-mark hold linux-headers-6.8.0-50
# sudo apt-mark hold linux-headers-6.8.0-50-generic
# sudo apt-mark hold linux-image-6.8.0-50-generic
