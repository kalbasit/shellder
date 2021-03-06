# vim:ft=zsh ts=2 sw=2 sts=2

#
# Segment drawing
#
CURRENT_BG='NONE'

#
# color scheme
#
SHELLDER_CONTEXT_BG=${SHELLDER_CONTEXT_BG:-238}
SHELLDER_CONTEXT_FG=${SHELLDER_CONTEXT_FG:-250}

SHELLDER_DIRECTORY_BG=${SHELLDER_DIRECTORY_BG:-234}
SHELLDER_DIRECTORY_FG=${SHELLDER_DIRECTORY_FG:-231}

SHELLDER_PROFILE_BG=${SHELLDER_PROFILE_BG:-'blue'}
SHELLDER_PROFILE_FG=${SHELLDER_PROFILE_FG:-'black'}

SHELLDER_GIT_CLEAN_BG=${SHELLDER_GIT_CLEAN_BG:-'green'}
SHELLDER_GIT_CLEAN_FG=${SHELLDER_GIT_CLEAN_FG:-'black'}
SHELLDER_GIT_DIRTY_BG=${SHELLDER_GIT_DIRTY_BG:-202}
SHELLDER_GIT_DIRTY_FG=${SHELLDER_GIT_DIRTY_FG:-'black'}

SHELLDER_VIRTUALENV_BG=${SHELLDER_VIRTUALENV_BG:-'blue'}
SHELLDER_VIRTUALENV_FG=${SHELLDER_VIRTUALENV_FG:-'black'}

SHELLDER_STATUS_BG=${SHELLDER_STATUS_BG:-'black'}
SHELLDER_STATUS_FG=${SHELLDER_STATUS_FG:-'default'}

# Special Powerline characters
() {
  local LC_ALL="" LC_CTYPE="en_US.UTF-8"
  SEGMENT_SEPARATOR=$'\ue0b0'
}

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}


#
# Prompt functions
#

# Context: user@hostname (who am I and where am I)
prompt_context() {
  local prompt
  if [[ "$USER" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    if [[ "$USER" != "$DEFAULT_USER" ]]; then
      prompt="%(!.%{%F{yellow}%}.)$USER@%m"
    else
      prompt="%(!.%{%F{yellow}%}.)%m"
    fi
    prompt_segment $SHELLDER_CONTEXT_BG $SHELLDER_CONTEXT_FG $prompt
  fi
}

# Profile: if there's an active profile, will be shown here
prompt_profile() {
  if [[ -n "${ACTIVE_PROFILE}" ]]; then
    local PROFILE_CHAR

    () {
      local LC_ALL="" LC_CTYPE="en_US.UTF-8"
      PROFILE_CHAR=$'\u270D' # ✍
    }

    prompt_segment $SHELLDER_PROFILE_BG $SHELLDER_PROFILE_FG "${PROFILE_CHAR} ${ACTIVE_PROFILE}"
  fi
}

# Git: branch/detached head, dirty status
prompt_git() {
  local repo_path
  repo_path=$(git rev-parse --git-dir 2>/dev/null)

  if [[ -n $repo_path ]]; then
    local PL_BRANCH_CHAR dirty bgcolor fgcolor mode ref

    () {
      local LC_ALL="" LC_CTYPE="en_US.UTF-8"
      PL_BRANCH_CHAR=$'\ue0a0' # 
    }

    dirty=$(command git status --porcelain --ignore-submodules=dirty 2> /dev/null)
    if [[ -n $dirty ]]; then
      if [[ -z $MSYS ]]; then
        bgcolor='yellow'
        fgcolor='black'
      else
        bgcolor=$SHELLDER_GIT_DIRTY_BG # vcs_info will be disabled with MSYS2, warn it with color
        fgcolor=$SHELLDER_GIT_DIRTY_FG
      fi
    else
      bgcolor=$SHELLDER_GIT_CLEAN_BG
      fgcolor=$SHELLDER_GIT_CLEAN_FG
    fi
    prompt_segment $bgcolor $fgcolor

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    # vcs_info is too slow with MSYS2 (~300ms with i7-6770K + SSD)
    if [[ -z $MSYS ]]; then
      autoload -Uz vcs_info
      zstyle ':vcs_info:*' enable git
      zstyle ':vcs_info:*' check-for-changes true
      zstyle ':vcs_info:*' stagedstr '✚'
      zstyle ':vcs_info:*' unstagedstr '●'
      zstyle ':vcs_info:*' formats ' %u%c'
      zstyle ':vcs_info:*' actionformats ' %u%c'
      vcs_info
    else
      if [[ -n $dirty ]]; then
        vcs_info_msg_0_=' !'
      fi
    fi

    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)"
    echo -n "${ref/refs\/heads\//$PL_BRANCH_CHAR }${vcs_info_msg_0_%% }${mode}"
  fi
}

prompt_hg() {
  local rev status
  if $(hg id >/dev/null 2>&1); then
    if $(hg prompt >/dev/null 2>&1); then
      if [[ $(hg prompt "{status|unknown}") = "?" ]]; then
        # if files are not added
        prompt_segment red white
        st='±'
      elif [[ -n $(hg prompt "{status|modified}") ]]; then
        # if any modification
        prompt_segment yellow black
        st='±'
      else
        # if working copy is clean
        prompt_segment green black
      fi
      echo -n $(hg prompt "☿ {rev}@{branch}") $st
    else
      st=""
      rev=$(hg id -n 2>/dev/null | sed 's/[^-0-9]//g')
      branch=$(hg id -b 2>/dev/null)
      if `hg st | grep -q "^\?"`; then
        prompt_segment red black
        st='±'
      elif `hg st | grep -q "^[MA]"`; then
        prompt_segment yellow black
        st='±'
      else
        prompt_segment green black
      fi
      echo -n "☿ $rev@$branch" $st
    fi
  fi
}

# Dir: current working directory
prompt_dir() {
  local dir
  if (( $+functions[shrink_path] )); then
    dir=$(shrink_path -f)
  else
    dir='%~'
  fi
  prompt_segment $SHELLDER_DIRECTORY_BG $SHELLDER_DIRECTORY_FG $dir
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
    prompt_segment $SHELLDER_VIRTUALENV_BG $SHELLDER_VIRTUALENV_FG "(`basename $virtualenv_path`)"
  fi
}

# Status: error + root + background jobs
prompt_status() {
  local symbols
  symbols=()
  [[ $RETVAL -eq 0 ]] && symbols+="%{%F{green}%}✓"
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}✘"
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}⚙"

  [[ -n "$symbols" ]] && prompt_segment $SHELLDER_STATUS_BG $SHELLDER_STATUS_FG "$symbols"
}


#
# Prompt
#
build_prompt() {
  RETVAL=$?
  prompt_status
  prompt_virtualenv
  prompt_context
  prompt_dir
  prompt_profile
  prompt_git
  prompt_hg
  prompt_end
}
setopt prompt_subst
PROMPT='%{%f%b%k%}$(build_prompt) '
