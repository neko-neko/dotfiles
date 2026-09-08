#!/bin/zsh
# The declarative Herdr plugin manifest, and the code that converges the machine
# onto it. setup/install/18_herdr_plugins.zsh applies it; setup/uninstall.zsh
# gives back only what this repo owns.
#
# config/herdr/config.toml binds keys to plugin actions, so the plugins those
# bindings name are part of the tracked configuration rather than incidental
# local state. What this replaces is config/herdr/plugins.json, a file herdr
# generates and this repo had committed: a snapshot of one machine's installed
# set, carrying absolute paths from that machine and still advertising a plugin
# that had already been removed from it.
#
# Sourced, never executed. Callers must source setup/util.zsh first.

: ${DOTFILES_DIR:=${0:A:h:h}}

# <plugin_id>|<path relative to the repo root>
# Owned by this repo: linked on install, unlinked on uninstall.
typeset -ga HERDR_LOCAL_PLUGINS=(
  'drop-upload|config/herdr/plugins/drop-upload'
)

# <plugin_id>|<owner/repo>|<commit ref>
# Not owned by this repo, only required by it. Installed at an exact ref so two
# machines get the same plugin, and never uninstalled: the human may have other
# reasons to keep one. The refs are the commits observed on the live machine
# these bindings were written against.
typeset -ga HERDR_GITHUB_PLUGINS=(
  'herdr-file-viewer|smarzban/herdr-file-viewer|498722e664d351ed5ab168f5afcac5fd4dce839a'
  'hunk.diff|edmundmiller/herdr-plugin-hunk|11ba5dcca4358203ca68f160becf6870cf016c18'
)

# Overridable, and resolved once to an absolute path. A bare `herdr` at call
# time is not trustworthy: ~/.zshenv reorders PATH, so the binary a caller or a
# test believes it pinned is not necessarily the one that runs.
herdr::_bin() {
  local bin="${HERDR_BIN:-$(command -v herdr)}"
  [[ -n ${bin} && ${bin} == /* && -x ${bin} ]] || return 1
  print -r -- "${bin}"
}

# Absolute too, and for the same reason as herdr::_bin. Ownership is decided
# from what this binary prints, so a relative JQ_BIN would make the answer
# depend on the directory the caller happened to be standing in.
herdr::_jq() {
  local bin="${JQ_BIN:-$(command -v jq)}"
  [[ -n ${bin} && ${bin} == /* && -x ${bin} ]] || return 1
  print -r -- "${bin}"
}

# What the installed set says about one plugin id, as `<kind>\t<root>\t<commit>`,
# or the empty string when herdr does not have it at all.
#
# A plugin id is not proof of ownership. `herdr plugin unlink drop-upload` used
# to run on the id alone, which meant a drop-upload linked from somebody else's
# checkout, or a GitHub plugin that happens to share the name, was removed by
# this repo's uninstall. The root and the kind are what distinguish them, so
# every decision below is made from this row rather than from the id.
#
# Two rows under one id is not a row this code can act on: `.[0]` picked
# whichever herdr happened to list first, so the kind and the root that decided
# ownership came from an arbitrary half of an ambiguous answer. It fails instead,
# and every caller turns that into a refusal to write.
herdr::_lookup() {
  local state="$1" id="$2" jq_bin="$3"
  print -r -- "${state}" | "${jq_bin}" -r --arg id "${id}" '
    [ .result.plugins[]? | select(.plugin_id == $id) ]
    | if length == 0 then ""
      elif length > 1 then
        error("duplicate plugin id in the installed set: " + $id)
      else ( .[0]
             | [ (.source.kind // ""), (.plugin_root // ""), (.source.resolved_commit // "") ]
             | @tsv )
      end
  '
}

# Idempotent: it reads the installed set first and only acts on the difference,
# so a rerun on a converged machine issues one read and no writes.
herdr::apply() {
  local bin jq_bin state entry id root repo ref rest row kind live_root commit

  if ! bin=$(herdr::_bin); then
    util::error 'herdr not found; install the baseline Brewfile first, or set HERDR_BIN to its absolute path'
    return 1
  fi

  if ! jq_bin=$(herdr::_jq); then
    util::error 'jq not found; install the baseline Brewfile first, or set JQ_BIN to its absolute path'
    return 1
  fi

  if ! state=$("${bin}" plugin list --json); then
    util::error 'herdr plugin list failed; is the herdr server reachable?'
    return 1
  fi

  for entry in ${HERDR_LOCAL_PLUGINS[@]}; do
    id=${entry%%|*}
    root="${DOTFILES_DIR}/${entry#*|}"

    if ! row=$(herdr::_lookup "${state}" "${id}" "${jq_bin}"); then
      util::error "could not read the installed set for ${id}"
      return 1
    fi
    kind=${row%%$'\t'*}
    live_root=${${row#*$'\t'}%%$'\t'*}

    if [[ -n ${row} ]]; then
      # Installed under this id already. Whether it is ours decides everything:
      # `plugin link` on top of somebody else's would silently repoint their
      # plugin at this checkout.
      if [[ ${kind} != local ]]; then
        util::error "herdr already has ${id} as a ${kind} plugin; this repo declares it as a local one"
        util::error "  remove it by hand (herdr plugin uninstall ${id}) and rerun"
        return 1
      fi
      if [[ ${live_root:A} != ${root:A} ]]; then
        util::error "herdr already has a local ${id} linked from ${live_root}, not from ${root}"
        util::error "  unlink it by hand and rerun if you want this checkout to own it"
        return 1
      fi
      continue
    fi

    if ! "${bin}" plugin link "${root}"; then
      util::error "herdr plugin link ${id} failed"
      return 1
    fi
    util::info "linked herdr plugin ${id}"
  done

  for entry in ${HERDR_GITHUB_PLUGINS[@]}; do
    id=${entry%%|*}
    rest=${entry#*|}
    repo=${rest%%|*}
    ref=${rest##*|}

    if ! row=$(herdr::_lookup "${state}" "${id}" "${jq_bin}"); then
      util::error "could not read the installed set for ${id}"
      return 1
    fi
    kind=${row%%$'\t'*}
    commit=${row##*$'\t'}

    if [[ -n ${row} && ${kind} != github ]]; then
      util::error "herdr already has ${id} as a ${kind} plugin; this repo declares it as a GitHub one"
      util::error "  unlink it by hand and rerun if you want this repo's version"
      return 1
    fi

    if [[ -n ${row} && ${commit} == "${ref}" ]]; then
      continue
    fi

    if ! "${bin}" plugin install "${repo}" --ref "${ref}" -y; then
      util::error "herdr plugin install ${repo} failed"
      return 1
    fi
    util::info "installed herdr plugin ${id} at ${ref}"
  done
}

# Uninstall gives back only what this repo linked. The GitHub plugins are the
# human's: removing them would be this script deciding what else on the machine
# is disposable.
herdr::unlink_local() {
  local bin jq_bin state entry id root row kind live_root failed=0

  if ! bin=$(herdr::_bin); then
    util::warning 'herdr not found; skipping herdr plugin unlink'
    return 0
  fi

  # Ownership cannot be established without reading the installed set, and
  # unlinking on the id alone is exactly the thing this guards against, so a
  # missing jq is a refusal rather than a fallback.
  if ! jq_bin=$(herdr::_jq); then
    util::error 'jq not found; cannot prove which plugins this repo owns, so nothing was unlinked'
    util::error '  install the baseline Brewfile first, or set JQ_BIN to its absolute path'
    return 1
  fi

  if ! state=$("${bin}" plugin list --json); then
    util::error 'herdr plugin list failed; is the herdr server reachable?'
    return 1
  fi

  for entry in ${HERDR_LOCAL_PLUGINS[@]}; do
    id=${entry%%|*}
    root="${DOTFILES_DIR}/${entry#*|}"

    if ! row=$(herdr::_lookup "${state}" "${id}" "${jq_bin}"); then
      util::error "could not read the installed set for ${id}"
      failed=1
      continue
    fi

    # Already gone. Uninstall is idempotent, so this is a success.
    if [[ -z ${row} ]]; then
      util::info "herdr plugin ${id} is not linked"
      continue
    fi

    kind=${row%%$'\t'*}
    live_root=${${row#*$'\t'}%%$'\t'*}

    if [[ ${kind} != local || ${live_root:A} != ${root:A} ]]; then
      util::warning "keeping herdr plugin ${id} (${kind} from ${live_root:-elsewhere}, not linked from ${root})"
      continue
    fi

    if ! "${bin}" plugin unlink "${id}"; then
      util::error "herdr plugin unlink ${id} failed"
      failed=1
      continue
    fi
    util::info "unlinked herdr plugin ${id}"
  done

  return ${failed}
}
