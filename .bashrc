
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
PS1='${debian_chroot:+($debian_chroot)}'"$(__ps1 color)"

### }}} MY_PS1

