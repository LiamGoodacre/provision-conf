### MY_PS1 {{{

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

  local now=$'$(date +\'%Y-%m-%d at %H:%M:%S\')'
  local timestamp='\n'"$violet"'τ '"$now""$blank"
  local location='\n'"$violet"'Ω '"$blue"'\u@\h '"$yellow"'\w'"$blank"
  local gitformat='\n'"$violet"'Δ '"$green"'%s'"$blank"
  local modeformat='\n'"$violet"'Π '"$red""${MY_MODE:-}""$blank"
  local mode="${MY_MODE:+$modeformat}"
  local prompt='\n'"$violet"'Σ'"$blank"' '

  local gitbit=''
  if &>/dev/null type __git_ps1; then
    gitbit='$(__git_ps1 '"'${gitformat}'"')'
  fi

  echo "${set_title}${cursor_reset}${timestamp}${location}${mode}${gitbit}${prompt}"
}

function __ps2() {
  local blank red yellow green blue violet

  if [ -n "${1}" ]; then
    blank='\[\033[00m\]'
    red='\[\033[01;31m\]'
    yellow='\[\033[01;33m\]'
    green='\[\033[01;32m\]'
    blue='\[\033[01;34m\]'
    violet='\[\033[01;35m\]'
  fi

  local prompt="$violet"'σ'"$blank"' '
  echo "${prompt}"
}

export GIT_PS1_SHOWDIRTYSTATE=1
export GIT_PS1_SHOWUNTRACKEDFILES=1
export GIT_PS1_SHOWUPSTREAM=auto
PS1='${debian_chroot:+($debian_chroot)}'"$(__ps1 color)"
PS2="$(__ps2 color)"

### }}} MY_PS1

if which tailscale &>/dev/null; then
  eval "$(tailscale completion bash)"
fi
