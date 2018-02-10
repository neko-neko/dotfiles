k8s_current_info() {
  if which kubectl > /dev/null; then
    cname=$(kubectl config current-context 2>/dev/null)

    if [[ $? != 0 ]]; then
      return
    fi
    args="--output=jsonpath={.contexts[?(@.name == \"${cname}\")].context.namespace}"
    namespace=$(kubectl config view "${args}")
    if [ -z $namespace ]; then
    namespace="default"
    fi
    echo "%{$fg[yellow]%}⎈ %{$reset_color%}%{$fg[cyan]%} ${cname}/${namespace} %{$reset_color%}"
  fi
}

+vi-git-untracked() {
  if [[ $(git rev-parse --is-inside-work-tree 2> /dev/null) == 'true' ]] && \
    git status --porcelain | grep '??' &> /dev/null ; then
    hook_com[staged]+='%{$fg[yellow]%}%{$reset_color%}'
  fi
}

+vi-git-st() {
  local ahead behind
  local -a gitstatus

  ahead=$(git rev-list ${hook_com[branch]}@{upstream}..HEAD 2>/dev/null | wc -l)
  (( $ahead )) && gitstatus+=( "%{$fg[green]%}+${ahead}%{$reset_color%}" )
  behind=$(git rev-list HEAD..${hook_com[branch]}@{upstream} 2>/dev/null | wc -l)
  (( $behind )) && gitstatus+=( "%{$fg[red]%}-${behind}%{$reset_color%}" )

  hook_com[misc]+=${(j:/:)gitstatus}
}

theme_precmd() {
  local colors=(
    "%F{81}"  # Turquoise
    "%F{166}" # Orange
    "%F{135}" # Purple
    "%F{161}" # Hotpink
    "%F{118}" # Limegreen
  )
  local branch_format="%{$colors[1]%}%b %f%c%u%m%f"
  local action_format="%{$colors[5]%}%a%f"
  local staged_format="%{$colors[5]%}%f"
  local unstaged_format="%{$colors[2]%}%f"

  zstyle ':vcs_info:git:*' enable bzr git hg svn
  zstyle ':vcs_info:git:*' check-for-changes true
  zstyle ':vcs_info:git:*' formats "${branch_format}"
  zstyle ':vcs_info:git:*' stagedstr "${staged_format}"
  zstyle ':vcs_info:git:*' unstagedstr "${unstaged_format}"
  zstyle ':vcs_info:git:*' actionformats "${branch_format}${action_format}"
  zstyle ':vcs_info:git*+set-message:*' hooks git-untracked git-st

  vcs_info

  local symbol='$'
  case ${USERNAME} in
  'root')
    symbol='#'
    ;;
  esac

  local new_line=$'\n'
  local vcs_message=''
  [[ ${vcs_info_msg_0_} != '' ]] && vcs_message="${vcs_info_msg_0_} " || vcs_message=''
  PROMPT="%{$colors[3]%}%n%f at %{$colors[2]%}%m%f $(k8s_current_info)%{$colors[5]%}(%T)%f%{$reset_color%}${new_line} %{$colors[5]%}%~%f ${vcs_message}${symbol} "
}

setopt prompt_subst
autoload -Uz vcs_info
autoload -Uz add-zsh-hook
add-zsh-hook precmd theme_precmd
