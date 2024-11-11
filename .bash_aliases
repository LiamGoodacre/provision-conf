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
