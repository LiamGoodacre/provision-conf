export EDITOR=nvim
export GIT_EDITOR="$EDITOR"
export VISUAL="$EDITOR"
export MY_CONFIG_DIR="$HOME"/.config/

modal() {
  local dir=$1; shift
  local mode=$1; shift
  local cmd=$1; shift
  (
    cd "$dir"
    $cmd "$@"
    MY_MODE="$mode" exec bash -il
  )
}

configs() {
  : | find "$MY_CONFIG_DIR" -name .git \
    | xargs dirname \
    | xargs -n1 basename
}

config-pick() {
  configs | gum filter --header "Choose a config"
}

config() {
  local which_config
  which_config=$(config-pick)
  if [ -z "$which_config" ]; then return 1; fi
  modal \
    "${MY_CONFIG_DIR}${which_config}" \
    "$which_config" \
    :
}

config-up() {
  local which_config
  which_config=$(config-pick)
  if [ -z "$which_config" ]; then return 1; fi
  modal \
    "${MY_CONFIG_DIR}${which_config}" \
    "$which_config" \
    git pull --rebase --autostash
}

complete_with_brs() {
  if [[ "${#COMP_WORDS[@]}" -gt 3 ]]; then return; fi
  COMPREPLY+=($(compgen -W "$(brs)" -- "${COMP_WORDS[-1]}"))
}

complete -F complete_with_brs v
