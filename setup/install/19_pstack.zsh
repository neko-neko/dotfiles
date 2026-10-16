#!/bin/zsh
# Deploys pstack (cursor/plugins) from a pinned upstream Git checkout, unchanged.
#
# The three parameters below are the whole declaration. Nothing in this repo
# vendors, patches, wraps or re-publishes the upstream bytes: the checkout is
# the only copy, it lives outside this repo, and the skills and subagents are
# reached through symlinks into it.
#
# It replaced an APM-managed install of the same package. APM 0.33.0 -- the
# latest release -- rejects the root AgentPlugins v1 manifest cursor/plugins now
# ships for the claude and hermes targets, so the manager could not resolve the
# package at all any more. `apm` stays in the baseline Brewfile; nothing in
# setup drives it.
#
# What a manager gave us and a checkout has to give back:
#   - a pinned, verifiable source  -> PSTACK_COMMIT, checked against HEAD
#   - one owner per deployed path  -> the preflight below, then setup/links.zsh
#   - no drift in the source       -> the clean-tree and origin checks
# The checkout is upstream's to write and nothing else's. Nothing here edits it
# to carry a local change; a local change is what the clean check refuses.
#
# Resolved from this file rather than ${HOME}/.dotfiles, like every other step.
# The default matters because a spec sources this file directly, without
# install.zsh having set DOTFILES_DIR first.
: ${DOTFILES_DIR:=${0:A:h:h:h}}
source "${0:A:h}/../util.zsh"
source "${0:A:h}/../links.zsh"

# Overridable so spec/pstack_spec.sh can drive the step against a local fixture
# repository instead of the network, and so a human can stage a checkout
# somewhere else without editing this file.
: ${PSTACK_REMOTE:=https://github.com/cursor/plugins.git}

# cursor/plugins publishes no tags and no releases, so a full commit SHA is the
# only thing there is to pin to. f713f142 is pstack 0.15.25.
: ${PSTACK_COMMIT:=f713f14203cd6420cec13cd7c55c32d598dbab68}

# Outside this repo on purpose. Upstream bytes are not this repo's content, and
# a checkout under ${DOTFILES_DIR} would show up in this repo's own `git status`
# and in its own skill glob.
: ${PSTACK_DIR:=${HOME}/.local/share/pstack/checkout}

util::info 'configure pstack from upstream Git...'

# Absolute and overridable, the same seam setup/setup.zsh gives the clone it
# does: ~/.zshenv reorders PATH, so a bare `git` resolved at call time is not
# necessarily the binary a caller or a test pinned.
git_bin="${GIT_BIN:-$(command -v git)}"
if [[ -z ${git_bin} || ${git_bin} != /* || ! -x ${git_bin} ]]; then
  util::error 'git not found; install the Xcode command line tools first, or set GIT_BIN to its absolute path'
  return 1
fi

pstack::_git() { "${git_bin}" -C "${PSTACK_DIR}" "$@" }

if [[ ! -d ${PSTACK_DIR}/.git ]]; then
  # A non-checkout sitting at the path is somebody else's, or the wreckage of an
  # interrupted clone. Either way it is not ours to clone over.
  if [[ -e ${PSTACK_DIR} ]]; then
    util::error "${PSTACK_DIR} exists and is not a Git checkout; move it aside and rerun"
    return 1
  fi
  if ! "${git_bin}" clone "${PSTACK_REMOTE}" "${PSTACK_DIR}"; then
    util::error "failed to clone ${PSTACK_REMOTE} into ${PSTACK_DIR}"
    return 1
  fi
fi

# Identity before anything is fetched into it. A checkout of some other
# repository at this path would otherwise be handed the pin and told to find it.
origin="$(pstack::_git remote get-url origin 2>/dev/null)"
if [[ ${origin} != ${PSTACK_REMOTE} ]]; then
  util::error "${PSTACK_DIR} has origin ${origin:-<none>}, not ${PSTACK_REMOTE}; leaving it alone"
  util::error "  move it aside and rerun, or set PSTACK_REMOTE to the remote it really has"
  return 1
fi

# Before the checkout below, not after. A tracked file edited in place is work
# somebody did, and `git checkout` is entitled to throw it away. This step would
# rather stop and say where it is.
if [[ -n "$(pstack::_git status --porcelain)" ]]; then
  util::error "${PSTACK_DIR} has local modifications; it is meant to hold upstream bytes only"
  util::error "  inspect with: git -C '${PSTACK_DIR}' status"
  return 1
fi

# Only when the pin is not already in the object store. A rerun on an unchanged
# pin then needs no network at all, and moving the pin fetches exactly once.
if ! pstack::_git cat-file -e "${PSTACK_COMMIT}^{commit}" 2>/dev/null; then
  # The SHA first: GitHub serves an unadvertised commit by name, which keeps a
  # pin bump from dragging down every branch. A remote that refuses one -- a
  # plain local repository, as the spec's fixture is -- falls back to the
  # advertised refs, which is where a pin reachable from a branch lives.
  if ! pstack::_git fetch --quiet origin "${PSTACK_COMMIT}" 2>/dev/null &&
     ! pstack::_git fetch --quiet origin; then
    util::error "failed to fetch ${PSTACK_COMMIT} from ${PSTACK_REMOTE}"
    return 1
  fi
  if ! pstack::_git cat-file -e "${PSTACK_COMMIT}^{commit}" 2>/dev/null; then
    util::error "${PSTACK_REMOTE} does not carry commit ${PSTACK_COMMIT}"
    return 1
  fi
fi

# Detached on purpose: this checkout tracks a pin, not a branch, and a branch
# here would invite a `git pull` that moves it. A fresh clone lands on the
# default branch, which is why being at the right commit is not on its own
# enough to skip this -- the branch has to go too, once.
if [[ "$(pstack::_git rev-parse HEAD 2>/dev/null)" != ${PSTACK_COMMIT} ]] ||
   pstack::_git symbolic-ref -q HEAD >/dev/null 2>&1; then
  if ! pstack::_git checkout --quiet --detach "${PSTACK_COMMIT}"; then
    util::error "failed to check out ${PSTACK_COMMIT} in ${PSTACK_DIR}"
    return 1
  fi
fi

# Re-read rather than trust the checkout's exit status. The pin is the contract,
# and this is the only place that proves the tree about to be linked is it.
head="$(pstack::_git rev-parse HEAD 2>/dev/null)"
if [[ ${head} != ${PSTACK_COMMIT} ]]; then
  util::error "${PSTACK_DIR} is at ${head:-<unknown>}, not the pinned ${PSTACK_COMMIT}"
  return 1
fi

pstack_root="${PSTACK_DIR}/pstack"
skills_root="${pstack_root}/skills"
agents_root="${pstack_root}/agents"

# Every source is resolved before the first link is made. A checkout missing
# half of what it should carry would otherwise deploy the half it has and report
# the rest one failure at a time.
skills=(${skills_root}/*/SKILL.md(N))
agents=(${agents_root}/*.md(N))
if (( ${#skills} == 0 )); then
  util::error "no skills under ${skills_root}; is ${PSTACK_DIR} a cursor/plugins checkout?"
  return 1
fi
if (( ${#agents} == 0 )); then
  util::error "no subagents under ${agents_root}; is ${PSTACK_DIR} a cursor/plugins checkout?"
  return 1
fi

# `<source>\t<target>` for everything this step deploys, resolved once and used
# by both passes below, so the preflight cannot check a different set from the
# one that gets linked.
#
# Two harnesses for the skills, Claude only for the subagents, and both named
# explicitly. Profiles, Cursor, Codex and every other harness on the machine are
# not this repo's to write into, and a recursive mirror is how they get written
# into by accident.
plan=()
for skill in ${skills}; do
  name=${skill:h:t}
  plan+=("${skills_root}/${name}"$'\t'"${HOME}/.claude/skills/${name}")
  plan+=("${skills_root}/${name}"$'\t'"${HOME}/.hermes/skills/${name}")
done
for agent in ${agents}; do
  plan+=("${agent}"$'\t'"${HOME}/.claude/agents/${agent:t}")
done

# Target preflight, read-only, before the first link.
#
# setup/links.zsh is convergent by design: one conflict stops that entry, not
# the run. That is right for a registry of unrelated files and wrong here,
# because these 110 entries are one package. A half-linked pstack is a set of
# skills that cite each other across a gap, so the whole deploy either goes or
# does not.
#
# Deliberately stricter than links::link, which would also adopt a symlink
# pointing elsewhere in this repo and replace a byte-identical real file.
# Neither can be this package's: the source is upstream, outside the repo, and
# the contract is one owner per path.
conflicts=()
for entry in ${plan}; do
  source=${entry%%$'\t'*}
  target=${entry#*$'\t'}
  if [[ -L ${target} ]]; then
    current="$(links::_points_at "${target}")" || current=''
    [[ ${current} == "${source:A}" ]] && continue
    conflicts+=("${target} -> ${current:-$(readlink -- "${target}")}")
  elif [[ -e ${target} ]]; then
    conflicts+=("${target} (a real $([[ -d ${target} ]] && print -n directory || print -n file))")
  fi
done

if (( ${#conflicts} )); then
  util::error "${#conflicts} pstack target(s) belong to something else; nothing was deployed"
  for conflict in ${conflicts}; do
    util::error "  ${conflict}"
  done
  util::error '  remove them by hand and rerun if you want this checkout to own them'
  return 1
fi

link_failed=0
for entry in ${plan}; do
  links::link "${entry%%$'\t'*}" "${entry#*$'\t'}" || link_failed=1
done

if (( link_failed )); then
  util::error 'some pstack links could not be deployed; resolve the conflicts above and rerun'
  return 1
fi

util::info "pstack ${PSTACK_COMMIT} deployed: ${#skills} skills to Claude and Hermes, ${#agents} subagents to Claude"
