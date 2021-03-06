k8s_current_info() {
  if which kubectl > /dev/null; then
    local cname=$(kubectl config current-context 2>/dev/null)
    if [[ "${cname}" = '' ]]; then
      return
    fi

    local args="--output=jsonpath={.contexts[?(@.name == \"${cname}\")].context.namespace}"
    local namespace=$(kubectl config view "${args}")
    if [[ -z $namespace ]]; then
      namespace='default'
    fi

    local regions=(
      "us-west1-a" "us-west1-b"
      "us-central1-a" "us-central1-b" "us-central1-c" "us-central1-f"
      "us-east1-b" "us-east1-c" "us-east1-d"
      "europe-west1-b" "europe-west1-c" "europe-west1-d"
      "asia-southeast1-a" "asia-southeast1-b"
      "asia-east1-a" "asia-east1-b" "asia-east1-c"
      "asia-northeast1-a" "asia-northeast1-b" "asia-northeast1-c"
    )

    for region in "${regions[@]}"; do
      cname=${cname%_${region}*}
    done
    
    echo "${cname}:${namespace}"
  fi
}

gcp_current_info() {
  local active_config=$(cat ~/.config/gcloud/active_config)
  local config_file=~/.config/gcloud/configurations/config_${active_config}
  local project_and_account=$(cat ${config_file} | grep -e 'project = ' -e 'account = ' | awk -F' = ' '{print $2}')
  local account=$(echo ${project_and_account} | cut -d$'\n' -f1)
  local project=$(echo ${project_and_account} | cut -d$'\n' -f2)

  if [[ "${account}" = 'null' ]] || [[ "${project}" = 'null' ]]; then
    return
  fi

  echo "${account}:${project}"
}

aws_current_profile() {
  echo "${AWS_PROFILE:-default}"
}

+vi-git-untracked() {
  if [[ $(git rev-parse --is-inside-work-tree 2> /dev/null) == 'true' ]] && \
    git status --porcelain | grep '??' &> /dev/null ; then
    hook_com[staged]+="%{$fg[yellow]%}%{$reset_color%}"
  fi
}

+vi-git-st() {
  local ahead behind
  local -a gitstatus

  remote=${$(git rev-parse --verify ${hook_com[branch]}@{upstream} --symbolic-full-name --abbrev-ref 2> /dev/null)}
  if [[ -n ${remote} ]] ; then
    ahead=$(git rev-list ${hook_com[branch]}@{upstream}..HEAD 2>/dev/null | wc -l)
    (( $ahead )) && gitstatus+=( "%{$fg[green]%}+${ahead}%{$reset_color%}" )
    behind=$(git rev-list HEAD..${hook_com[branch]}@{upstream} 2>/dev/null | wc -l)
    (( $behind )) && gitstatus+=( "%{$fg[red]%}-${behind}%{$reset_color%}" )

    hook_com[misc]+=${(j:/:)gitstatus}
  fi
}

theme_precmd() {
  local colors=(
    "%F{81}"  # Turquoise
    "%F{166}" # Orange
    "%F{135}" # Purple
    "%F{118}" # Limegreen
  )
  local branch_format="%{$colors[1]%}%b %f%c%u%m%f"
  local action_format="%{$colors[4]%}%a%f"
  local staged_format="%{$colors[4]%}%f"
  local unstaged_format="%{$colors[2]%}%f"

  zstyle ':vcs_info:git:*' enable bzr git hg svn
  zstyle ':vcs_info:git:*' check-for-changes true
  zstyle ':vcs_info:git:*' formats "${branch_format}"
  zstyle ':vcs_info:git:*' stagedstr "${staged_format}"
  zstyle ':vcs_info:git:*' unstagedstr "${unstaged_format}"
  zstyle ':vcs_info:git:*' actionformats "${branch_format}${action_format}"
  zstyle ':vcs_info:git*+set-message:*' hooks git-st git-untracked
  vcs_info

  local symbol='$'
  case ${USERNAME} in
  'root')
    symbol='#'
    ;;
  esac

  local aws_info="%{$fg[yellow]%}$(aws_current_profile)%{$reset_color%}"
  local gcp_info="$(gcp_current_info)"
  local k8s_info="$(k8s_current_info)"
  local new_line=$'\n'
  local vcs_message=''

  [[ ${vcs_info_msg_0_} != '' ]] && vcs_message="${vcs_info_msg_0_} " || vcs_message=''
  [[ ${gcp_info} != '' ]] && gcp_info=" / %{$fg[blue]%}${gcp_info}%{$reset_color%}" || gcp_info=''
  [[ ${k8s_info} != '' ]] && k8s_info=" / %{$fg[cyan]%}${k8s_info}%{$reset_color%}" || k8s_info=''

  PROMPT="%{$colors[3]%}%n%f at %{$colors[2]%}%m%f ${aws_info}${gcp_info}${k8s_info} %{$colors[4]%}(%T)%f%{$reset_color%}${new_line} %{$colors[4]%}%~%f ${vcs_message}${symbol} "
}

setopt prompt_subst
autoload -Uz vcs_info
autoload -Uz add-zsh-hook
add-zsh-hook precmd theme_precmd
