#!/bin/zsh
# The registry of everything this repo deploys, and the only code that creates
# or removes those links. setup/setup.zsh and setup/uninstall.zsh both read it,
# so the two halves cannot drift apart.
#
# It replaces two things that had already drifted. Deployment was an implicit
# glob over the top level with a deny list, which meant every file added to the
# repo root got linked into $HOME by default: that is where ~/.Brewfile,
# ~/.CLAUDE.md and ~/.spec came from. Removal was a hand-maintained list naming
# six paths this repo has not shipped for years and missing most of what the
# glob actually created.
#
# Sourced, never executed. Callers must source setup/util.zsh first.

: ${DOTFILES_DIR:=${0:A:h:h}}

# entry := <source, relative to the repo root>|<target>
# target := HOME/<rest> | XDG/<rest>
#
# A whole directory is linked only when this repo is the sole writer. A
# directory something else writes into gets one entry per tracked file, so the
# live directory stays real and keeps the runtime state it accumulates.
typeset -ga DOTFILES_LINKS=(
  # Top-level dotfiles, enumerated rather than globbed.
  'aliases|HOME/.aliases'
  'bin|HOME/.bin'
  'editorconfig|HOME/.editorconfig'
  'functions|HOME/.functions'
  'gemrc|HOME/.gemrc'
  'gitconfig|HOME/.gitconfig'
  'gitignore_global|HOME/.gitignore_global'
  'hushlogin|HOME/.hushlogin'
  'zshenv|HOME/.zshenv'
  'zshrc|HOME/.zshrc'

  # Stateless config directories: nothing but this repo writes into them.
  'config/ccstatusline|XDG/ccstatusline'
  'config/ghostty|XDG/ghostty'
  'config/mise|XDG/mise'
  'config/sesh|XDG/sesh'
  'config/sheldon|XDG/sheldon'
  'config/starship.toml|XDG/starship.toml'

  # herdr keeps sockets, logs, session.json, plugins.json and its installed
  # plugin trees in this directory. Only the declarative config is ours.
  'config/herdr/config.toml|XDG/herdr/config.toml'

  # Karabiner-Elements owns this directory too: it writes automatic_backups/
  # into it and rewrites karabiner.json in place, through the link.
  'config/karabiner/karabiner.json|XDG/karabiner/karabiner.json'
  'config/karabiner/assets/complex_modifications/1513924035.json|XDG/karabiner/assets/complex_modifications/1513924035.json'
  'config/karabiner/assets/complex_modifications/1513924106.json|XDG/karabiner/assets/complex_modifications/1513924106.json'
  'config/karabiner/assets/complex_modifications/1513924179.json|XDG/karabiner/assets/complex_modifications/1513924179.json'
)

# Links older versions of this repo created that nothing declares any more.
# Uninstall removes them, and only while they still point into this repo.
#
# The first three are the implicit glob's collateral. The fourth is the nested
# link `ln -s` leaves behind when its target directory already exists, which is
# how ~/.config/karabiner/karabiner came to point at the repo's karabiner
# directory from inside the live one.
#
# The fifth is the whole-directory link an older registry made of config/herdr,
# before herdr started keeping sockets, logs and installed plugins in it. It is
# removed only while it is a symlink into this repo, so a machine whose
# ~/.config/herdr is the real live directory loses nothing.
typeset -ga DOTFILES_OBSOLETE_LINKS=(
  'HOME/.Brewfile'
  'HOME/.CLAUDE.md'
  'HOME/.spec'
  'XDG/karabiner/karabiner'
  'XDG/herdr'
)

links::_target() {
  local spec="$1"
  case ${spec} in
    HOME/*) print -r -- "${HOME}/${spec#HOME/}" ;;
    XDG/*)  print -r -- "${XDG_CONFIG_HOME:-${HOME}/.config}/${spec#XDG/}" ;;
    *)      return 1 ;;
  esac
}

# One `<source>\t<target>` line per entry, both absolute.
links::registry() {
  local entry target
  for entry in ${DOTFILES_LINKS[@]}; do
    if ! target=$(links::_target "${entry#*|}"); then
      util::error "unrecognised registry target: ${entry}"
      return 1
    fi
    printf '%s\t%s\n' "${DOTFILES_DIR}/${entry%%|*}" "${target}"
  done
}

# Fails on an entry it cannot resolve, like links::registry. Skipping one
# quietly meant a typo in the list above turned into an obsolete link that was
# simply never removed, on every machine, with nothing said about it.
links::obsolete() {
  local spec target
  for spec in ${DOTFILES_OBSOLETE_LINKS[@]}; do
    if ! target=$(links::_target "${spec}"); then
      util::error "unrecognised obsolete-link target: ${spec}"
      return 1
    fi
    print -r -- "${target}"
  done
}

# Where a symlink actually points, as an absolute canonical path.
#
# Raw `readlink` text is not an identity. `ln -s ../../.dotfiles/zshrc` and
# `ln -s /Users/me/.dotfiles/zshrc` name the same file, and comparing the text
# called the first one somebody else's: install refused to touch a link it had
# every right to own, and uninstall left it behind. `:A` resolves the relative
# form against the link's own directory and canonicalises what is left, which is
# what makes the two forms compare equal.
#
# A dangling link resolves too. `:A` on the link itself would stop at the link
# when the target does not exist, so the raw text is absolutised instead.
links::_points_at() {
  local link="$1" raw
  raw="$(readlink -- "${link}")" || return 1
  [[ ${raw} == /* ]] || raw="${link:h}/${raw}"
  print -r -- "${raw:A}"
}

# Creates one link, or refuses and explains. Never removes anything it cannot
# prove this repo put there.
links::link() {
  local source="$1" target="$2" current repo

  if [[ ! -e ${source} ]]; then
    util::error "missing source: ${source}"
    return 1
  fi

  if [[ ! -d ${target:h} ]] && ! mkdir -p "${target:h}"; then
    util::error "cannot create ${target:h}"
    return 1
  fi

  if [[ -L ${target} ]]; then
    current="$(links::_points_at "${target}")" || current=''
    repo="${DOTFILES_DIR:A}"
    [[ -n ${current} && ${current} == "${source:A}" ]] && return 0

    # Ours, but aimed at the wrong file in this repo. Repointing is safe:
    # -n keeps ln from following the link into a directory, which is what stops
    # a link to a repo *directory* growing a nested link inside it.
    if [[ -n ${current} && ${current} == "${repo}"/* ]]; then
      ln -sfn "${source}" "${target}" || return 1
      util::info "relinked ${target} -> ${source}"
      return 0
    fi

    util::error "${target} is a symlink to ${current:-$(readlink -- "${target}")}, not to this repo; leaving it alone"
    util::error "  remove it by hand and rerun if you want this repo to own it"
    return 1
  fi

  if [[ -e ${target} ]]; then
    # Already the same file, reached by another route: an older
    # whole-directory link sitting above it. Deleting it would delete the
    # repo's own copy, so this branch has to come before the byte comparison.
    [[ ${target} -ef ${source} ]] && return 0

    if [[ -f ${target} && -f ${source} ]] && cmp -s "${target}" "${source}"; then
      rm -f "${target}" || return 1
      ln -s "${source}" "${target}" || return 1
      util::info "linked ${target} -> ${source} (replaced an identical copy)"
      return 0
    fi

    util::error "${target} already exists and differs from ${source}; leaving it alone"
    util::error "  compare with: diff '${target}' '${source}'"
    return 1
  fi

  ln -s "${source}" "${target}" || return 1
  util::info "linked ${target} -> ${source}"
}

# Removes one link, and only when it resolves to exactly the source that
# declared it. Anything else is someone else's and stays.
links::unlink() {
  local source="$1" target="$2" current

  if [[ ! -L ${target} ]]; then
    [[ -e ${target} ]] && util::warning "keeping ${target} (not a symlink)"
    return 0
  fi

  current="$(links::_points_at "${target}")" || current=''
  if [[ -z ${current} || ${current} != "${source:A}" ]]; then
    util::warning "keeping ${target} (symlink to $(readlink -- "${target}"), not to ${source})"
    return 0
  fi

  if ! unlink "${target}"; then
    util::error "could not remove ${target}"
    return 1
  fi
  util::info "unlinked ${target}"
}

# Convergent: a conflict stops that entry, not the run. Everything deployable is
# deployed, and the nonzero return says at least one entry needs a human.
#
# The registry is resolved up front rather than piped in. Read through a
# redirection, a registry that failed to resolve would produce no lines, the
# loop would do nothing, and the deploy would report success having deployed
# nothing at all.
links::install_all() {
  local source target failed=0 entries

  if ! entries=$(links::registry); then
    util::error 'the deploy registry could not be resolved; nothing was deployed'
    return 1
  fi

  while IFS=$'\t' read -r source target; do
    [[ -n ${source} && -n ${target} ]] || continue
    links::link "${source}" "${target}" || failed=1
  done <<< "${entries}"

  return ${failed}
}

links::uninstall_all() {
  local source target entries failed=0

  if ! entries=$(links::registry); then
    util::error 'the deploy registry could not be resolved; nothing was removed'
    return 1
  fi

  while IFS=$'\t' read -r source target; do
    [[ -n ${source} && -n ${target} ]] || continue
    links::unlink "${source}" "${target}" || failed=1
  done <<< "${entries}"

  return ${failed}
}

# Also runs during setup, not just uninstall. An old install carries links this
# registry no longer declares, and a whole-directory link sitting where a real
# directory now belongs would turn every file-level entry underneath it into a
# write back into this repo. Converging means removing those first.
# The list is resolved up front, for the same reason links::install_all resolves
# the registry up front. Read through a process substitution, a list that failed
# to resolve produced no lines and a zero status: the loop removed whatever it
# had already printed, said nothing about the entry it could not resolve, and
# the caller was told the cleanup had succeeded.
links::remove_obsolete() {
  local target current repo failed=0 targets

  repo="${DOTFILES_DIR:A}"

  if ! targets=$(links::obsolete); then
    util::error 'the obsolete-link list could not be resolved; nothing was removed'
    return 1
  fi

  while IFS= read -r target; do
    [[ -n ${target} ]] || continue
    [[ -L ${target} ]] || continue
    current="$(links::_points_at "${target}")" || current=''
    if [[ -z ${current} || ${current} != "${repo}"/* ]]; then
      util::warning "keeping ${target} (symlink to $(readlink -- "${target}"), not into this repo)"
      continue
    fi
    if ! unlink "${target}"; then
      util::error "could not remove obsolete link ${target}"
      failed=1
      continue
    fi
    util::info "removed obsolete link ${target}"
  done <<< "${targets}"

  return ${failed}
}
