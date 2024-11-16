#!/usr/bin/env bash

set -euo pipefail
shopt -s inherit_errexit

confirm_with() {
  local response=n
  read -p "$1 [y/N] " response
  if [[ "$response" == "y" ]]; then echo y; else echo n; fi
}

confirm_modify() {
  local path=$1; shift
  local response=y

  if [[ -f "$path" ]]; then
    response=n
    read -p "Modify $path? [y/N] " response
  fi

  if [[ "$response" == "y" ]]; then echo y; else echo n; fi
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

install_config \
  'provision-conf/.bashrc' \
  "$HOME"/.bashrc \
  "$HOME"/.config/provision-conf/.bashrc

install_config \
  'provision-conf/.bash_aliases' \
  "$HOME"/.bash_aliases \
  "$HOME"/.config/provision-conf/.bash_aliases

mkdir -p "$HOME"/.config/home-manager
ln -s "$HOME"/.config/provision-conf/home.nix "$HOME"/.config/home-manager/home.nix

sudo apt update
sudo apt upgrade

if [[ "$LANG" != "en_GB.UTF-8" ]]; then
  sudo locale-gen en_GB.UTF-8
  sudo update-locale LANG=en_GB.UTF-8
  sudo localectl set-locale LANG=en_GB.UTF-8
fi

sudo snap install alacritty 1password htop gimp
sudo apt install build-essential zlib1g-dev git curl xsel xclip ripgrep tmux gnome-tweaks fzf tree vlc

gsettings set org.gnome.desktop.interface gtk-enable-primary-paste false

sudo tee /usr/bin/default-terminal <<"EOF"
#!/usr/bin/env bash
exec snap run alacritty -e tmux new -A -s default
EOF
sudo chmod +x /usr/bin/default-terminal
sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/default-terminal 50

if >/dev/null pgrep firefox; then
  >&2 echo "Firefox is running, skipping setting tweaks"
else
  ### whilst firefox is closed, and you've ran it at least once
  while read -r f; do
    if grep -q 'middlemouse.paste' "$f"; then continue; fi
    echo 'user_pref("middlemouse.paste", false);' >> "$f"
  done <<< $( find "$HOME"/snap/firefox/common/.mozilla/firefox/ -name prefs.js )
fi

### Set up ssh agent in 1Password
### Possibly add new ssh key to GitHub

### Install Hack Nerd Font
if [[ "$(confirm_with 'Install Hack Nerd Font?')" == "y" ]]; then
  (
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT
    curl -L https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Hack.zip -o "$tmpdir"/Hack.zip
    cd "$tmpdir"
    unzip Hack.zip
    find ~/.local/share/fonts/ -name 'HackNerdFont*.ttf' -exec rm {} \;
    cp -r ./*.ttf ~/.local/share/fonts/
    fc-cache -fv
  )
fi

test -d "$HOME"/.config/tokyonight-theme || git clone https://github.com/folke/tokyonight.nvim.git "$HOME"/.config/tokyonight-theme
test -d "$HOME"/.config/alacritty-conf || git clone git@github.com:LiamGoodacre/alacritty-conf.git "$HOME"/.config/alacritty-conf
rm -f "$HOME"/.alacritty.toml
ln -s /home/liam/.config/alacritty-conf/.alacritty.toml "$HOME"/.alacritty.toml

### Note: ensure bash >=5
test -d "$HOME"/.config/tmux-conf || git clone git@github.com:LiamGoodacre/tmux-conf.git "$HOME"/.config/tmux-conf
rm -f "$HOME"/.tmux.conf
ln -s /home/liam/.config/tmux-conf/.tmux.conf "$HOME"/.tmux.conf

### Needed for neovim Mason to install bzl & PureScript lsps
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
(
  export NVM_DIR="$HOME/.config/nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  nvm install node
  nvm use node
)

curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
sudo rm /usr/bin/nvim
sudo mv nvim.appimage /usr/bin/nvim
sudo chmod +x /usr/bin/nvim
test -d "$HOME"/.config/nvim || git clone git@github.com:LiamGoodacre/nvim-conf.git "$HOME"/.config/nvim
for e in editor ex vi view pico; do
  sudo update-alternatives --install `which $e` $e `which nvim` 50
done

if [[ "$(confirm_with 'Install ghcup?')" == "y" ]]; then
  curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
fi

if [[ "$(confirm_with 'Install/upgrade tailscale?')" == "y" ]]; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

if which nix &>/dev/null; then
  >&2 echo "Nix already installed"
elif [[ "$(confirm_with 'Install Nix?')" == "y" ]]; then
  sh <(curl -L https://nixos.org/nix/install) --daemon
  nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
  nix-channel --update
  nix-shell '<home-manager>' -A install
  home-manager build && home-manager switch
fi

if [[ "$(confirm_with 'Install OBS Studio?')" == "y" ]]; then
  sudo add-apt-repository ppa:obsproject/obs-studio
  sudo apt install obs-studio
fi

# ### for ghc dev
# sudo apt-get install build-essential git autoconf python3 libgmp-dev libnuma-dev libncurses-dev
# cabal v2-install happy-2.0.2
# cabal v2-install alex

# ### Fingerprint reader & auth
# sudo apt install libpam-fprintd fprintd
# fprintd-enroll # to enroll fingerprint
# sudo pam-auth-update # Then select "Fingerprint authentication"
