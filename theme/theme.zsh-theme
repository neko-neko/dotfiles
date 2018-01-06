theme_precmd() {
  local colors=(
    "%F{81}"  # Turquoise
    "%F{166}" # Orange
    "%F{135}" # Purple
    "%F{161}" # Hotpink
    "%F{118}" # Limegreen
  )
  local branch_format="${colors[1]}%b %f%c%u%m%f"
  local action_format="${colors[5]}%a%f"
  local staged_format="${colors[5]}%f"
  local unstaged_format="${colors[2]}%f"

  zstyle ':vcs_info:*' enable bzr git hg svn
  zstyle ':vcs_info:*' check-for-changes true
  zstyle ':vcs_info:*' formats "${branch_format}"
  zstyle ':vcs_info:*' stagedstr "${staged_format} "
  zstyle ':vcs_info:*' unstagedstr "${unstaged_format} "
  zstyle ':vcs_info:*' actionformats "${branch_format}${action_format}"

  vcs_info

  PROMPT="${colors[3]}%n%f at ${colors[2]}%m%f in ${colors[5]}%~%f ${vcs_info_msg_0_}"
  RPROMPT="${colors[5]}(%T)%f"
}

setopt prompt_subst
autoload -Uz vcs_info
autoload -Uz add-zsh-hook
add-zsh-hook precmd theme_precmd
