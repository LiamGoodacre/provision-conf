#!/usr/bin/env bash

set -euo pipefail
shopt -s inherit_errexit

confirm_modify() {
  local path=$1; shift
  local response=y

  if [[ -f "$path" ]]; then
    response=n
    read -p "Modify $path? [y/N] " response
  fi

  if [[ "$response" == "y" ]]; then
    echo y
  else
    echo n
  fi
}

if [[ "$(confirm_modify "$HOME/.bash_aliases")" == "y" ]]; then
  tee "$HOME"/.bash_aliases <<"EOF"
export EDITOR=nvim
export VISUAL=nvim
export MY_CONFIG_DIR="$HOME"/.config/

modal() {
  local dir=$1; shift
  local mode=$1; shift
  (cd "$dir" && MY_MODE="$mode" exec bash -il)
}

configs() {
  : | find "$MY_CONFIG_DIR" -name .git \
    | xargs dirname \
    | xargs -n1 basename
}

config() {
  local which_config
  which_config=$( configs | fzf --reverse )
  modal "${MY_CONFIG_DIR}${which_config}" "$which_config"
}
EOF
fi

if [[ "$(confirm_modify "$HOME/.bashrc")" == "y" ]]; then
  tee --append "$HOME"/.bashrc <<"EOF"
function __ps1() {
  local blank red yellow green blue violet

  if [ -n "${1}" ]; then
    blank='\[\033[00m\]'
    red='\[\033[01;31m\]'
    yellow='\[\033[01;33m\]'
    green='\[\033[01;32m\]'
    blue='\[\033[01;34m\]'
    violet='\[\033[01;35m\]'
  fi

  local set_title='\033]0;$(pwd) | $(hostname -f)\007'
  local cursor_reset='\r$(tput cnorm)'

  local location='\n'"$violet"'Σ \u@\h: '"$yellow"'\w'"$blank"
  local gitformat='\n'"$violet"'Δ '"$green"'%s'"$blank"
  local mode="${MY_MODE:+\n"$violet"Π mode: "$red""${MY_MODE}""$blank"}"
  local prompt='\n'"$violet"'∀'"$blank"' '

  local gitbit=''
  if &>/dev/null type __git_ps1; then
    gitbit='$(__git_ps1 '"'${gitformat}'"')'
  fi

  echo "${set_title}${cursor_reset}${location}${gitbit}${mode}${prompt}"
}

export GIT_PS1_SHOWDIRTYSTATE=1
export GIT_PS1_SHOWUNTRACKEDFILES=1
export GIT_PS1_SHOWUPSTREAM=auto
PS1='${debian_chroot:+($debian_chroot)}'"$(__ps1 "${color_prompt}")"
unset color_prompt force_color_prompt
EOF
fi

sudo apt update
sudo apt upgrade

if [[ "$LANG" != "en_GB.UTF-8" ]]; then
  sudo locale-gen en_GB.UTF-8
  sudo update-locale LANG=en_GB.UTF-8
  sudo localectl set-locale LANG=en_GB.UTF-8
fi

sudo snap install alacritty 1password htop gimp
sudo apt install build-essential zlib1g-dev git curl xsel xclip ripgrep tmux gnome-tweaks fzf

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
  # whilst firefox is closed, and you've ran it at least once
  while read -r f; do
    if grep -q 'middlemouse.paste' "$f"; then continue; fi
    echo 'user_pref("middlemouse.paste", false);' >> "$f"
  done <<< $( find "$HOME"/snap/firefox/common/.mozilla/firefox/ -name prefs.js )
fi

# Set up ssh agent in 1Password
# Possibly add new ssh key to GitHub

# Install Hack Nerd Font
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

test -d "$HOME"/.config/tokyonight-theme || git clone https://github.com/folke/tokyonight.nvim.git "$HOME"/.config/tokyonight-theme
test -d "$HOME"/.config/alacritty-conf || git clone git@github.com:LiamGoodacre/alacritty-conf.git "$HOME"/.config/alacritty-conf
rm -f "$HOME"/.alacritty.toml
ln -s /home/liam/.config/alacritty-conf/.alacritty.toml "$HOME"/.alacritty.toml

# Note: ensure bash >=5
test -d "$HOME"/.config/tmux-conf || git clone git@github.com:LiamGoodacre/tmux-conf.git "$HOME"/.config/tmux-conf
rm -f "$HOME"/.tmux.conf
ln -s /home/liam/.config/tmux-conf/.tmux.conf "$HOME"/.tmux.conf

# Needed for neovim Mason to install bzl & PureScript lsps
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
(
  NVM_DIR="$HOME/.config/nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
  nvm install node latest
  nvm use node latest
)

curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
sudo rm /usr/bin/nvim
sudo mv nvim.appimage /usr/bin/nvim
sudo chmod +x /usr/bin/nvim
test -d "$HOME"/.config/nvim || git clone git@github.com:LiamGoodacre/nvim-conf.git "$HOME"/.config/nvim

curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh

curl -fsSL https://tailscale.com/install.sh | sh
if ! grep -q 'tailscale completion bash' "$HOME"/.bashrc; then
  tee --append "$HOME"/.bashrc <<"EOF"
eval "$(tailscale completion bash)"
EOF
fi

if >/dev/null which nix; then
  >&2 echo "Nix already installed"
else
  sh <(curl -L https://nixos.org/nix/install) --daemon
fi

# sudo add-apt-repository ppa:obsproject/obs-studio
# sudo apt install obs-studio

# for ghc dev
# sudo apt-get install build-essential git autoconf python3 libgmp-dev libnuma-dev libncurses-dev
# cabal v2-install happy-2.0.2
# cabal v2-install alex
