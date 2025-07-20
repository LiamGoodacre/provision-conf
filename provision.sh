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
gsettings set org.gnome.desktop.peripherals.keyboard delay 300 # default is 500
gsettings set org.gnome.desktop.peripherals.keyboard repeat-interval 20 # default is 30

sudo apt update
sudo apt upgrade

# Basic tools {{{
sudo apt install \
  build-essential \
  curl \
  fonts-hack-ttf \
  fzf \
  git \
  gnome-tweaks \
  moreutils \
  python3-pip \
  python3-venv \
  ripgrep \
  tmux \
  tree \
  vlc \
  xclip \
  xsel \
  zlib1g-dev
sudo snap install \
  htop
# }}} Basic tools

# Configure git {{{
git config --global diff.color always
git config --global diff.colorMoved zebra
git config --global diff.colorMovedWS allow-indentation-change
git config --global rebase.autostash true
git config --global rebase.updateRefs true
# }}} Configure git

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
ensure_git "$HOME"/.config/ghostty git@github.com:LiamGoodacre/ghostty-conf.git
ensure_git "$HOME"/.config/tmux-conf git@github.com:LiamGoodacre/tmux-conf.git
ensure_git "$HOME"/.config/nvim git@github.com:LiamGoodacre/nvim-conf.git

tasks=(
  "1password"
  "bazel"
  "configure-git"
  "docker"
  "dotnet"
  "fingerprint"
  "ghcup"
  "ghostty"
  "godot"
  "jujitsu"
  "neovim"
  "nvm-node"
  "obs-studio"
  "rust"
  "tailscale"
  "tmux-conf"
  "zig"
)

gum filter \
  --header "Select tasks to run" \
  --no-limit \
  "${tasks[@]}" | \
while read -r task; do

  case "$task" in
    "1password") # 1Password {{{
      curl -L https://downloads.1password.com/linux/debian/amd64/stable/1password-latest.deb > ~/Downloads/1password-latest.deb
      sudo apt install ~/Downloads/1password-latest.deb
    ;; # }}} 1Password

    "fingerprint") # Fingerprint reader {{{
      sudo apt install libpam-fprintd fprintd
      fprintd-enroll # to enroll fingerprint
      sudo pam-auth-update # Then select "Fingerprint authentication"
    ;; # }}} Fingerprint reader

    "ghostty") # Ghostty {{{
      sudo snap install ghostty --classic
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
    ;; # }}} Ghostty

    "ghcup") # GHCup {{{
      curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
    ;; # }}} GHCup

    "tmux-conf") # tmux-conf {{{
      ### Note: ensure bash >=5
      rm -f "$HOME"/.tmux.conf
      ln -s /home/liam/.config/tmux-conf/.tmux.conf "$HOME"/.tmux.conf
    ;; # }}} tmux-conf

    "nvm-node") # NVM/Node {{{
      ### Needed for neovim Mason to install bzl & PureScript lsps
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
      (
        export NVM_DIR="$HOME/.config/nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
        nvm install node latest
        nvm use node
      )
    ;; # }}} NVM/Node

    "neovim") # Neovim {{{
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
      )
    ;; # }}} Neovim

    "jujitsu") # Jujitsu {{{
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
    ;; # }}} Jujitsu

    "tailscale") # Tailscale {{{
      curl -fsSL https://tailscale.com/install.sh | sh
    ;; # }}} Tailscale

    "obs-studio") # OBS Studio {{{
      sudo add-apt-repository ppa:obsproject/obs-studio
      sudo apt install obs-studio
    ;; # }}} OBS Studio

    "godot") # Godot {{{
      sudo snap install godot4
    ;; # }}} Godot

    "bazel") # Bazelisk {{{
      curl -L https://github.com/bazelbuild/bazelisk/releases/download/v1.26.0/bazelisk-amd64.deb > ~/Downloads/bazelisk-amd64.deb
      sudo apt install ~/Downloads/bazelisk-amd64.deb
      if [[ -f /usr/bin/bazel ]]; then
        sudo rm /usr/bin/bazel
      fi
      sudo ln -s /usr/bin/bazelisk /usr/bin/bazel
      # rules_haskell requires some extra packages
      sudo apt install build-essential libffi-dev libgmp-dev libtinfo6 libtinfo-dev python3 openjdk-11-jdk
    ;; # }}} Bazelisk

    "docker") # Docker {{{
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
    ;; # }}} Docker

    "dotnet") # dotnet {{{
      sudo add-apt-repository ppa:dotnet/backports
      sudo apt-get update
      sudo apt-get install -y dotnet-sdk-9.0 aspnetcore-runtime-9.0
    ;; # }}} dotnet

    "rust") # Rust {{{
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
      #source "$HOME"/.cargo/env
      # Install rust-analyzer
      #rustup component add rust-src
      #rustup component add rust-analyzer-preview
    ;; # }}} Rust

    "zig") # Zig {{{
      sudo snap install zig --classic --beta
    ;; # }}} Zig

  esac
done

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
