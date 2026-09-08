#!/bin/zsh
# Bootstrap entry point.
#
# Two ways in, and they need different update behaviour. The curl one-liner in
# README.md has no checkout yet, so it clones into $DOTFILES_DIR and updates
# that clone on a rerun. CI and anyone exercising a working tree point
# DOTFILES_DIR at the checkout and set DOTFILES_NO_UPDATE=1, so the commit under
# test is the commit that runs. Without that seam CI checked out a commit and
# then cloned master from GitHub over the top of it, and every green run was a
# statement about master rather than about the push.
#
# FORCE is deliberately not set here. It used to be, unconditionally, which made
# every prompt in the rest of bootstrap answer itself even when a human was
# sitting at the terminal. CI sets FORCE=1 in the environment instead.

: ${DOTFILES_DIR:=${HOME}/.dotfiles}
: ${DOTFILES_REPO_URL:=https://github.com/neko-neko/dotfiles.git}

# Overridable and resolved once, the same seam BREW_BIN and MISE_BIN give the
# later steps. This one runs before any of this repo is on disk, so it is the
# only way a test can exercise the clone and update paths at all.
#
# Absolute, like BREW_BIN and MISE_BIN. A relative GIT_BIN is resolved against
# whatever directory the caller happened to be standing in, so the binary that
# clones this repo would depend on the shell's cwd rather than on the seam.
git_bin="${GIT_BIN:-$(command -v git)}"
if [[ -z ${git_bin} || ${git_bin} != /* || ! -x ${git_bin} ]]; then
  print -u2 'git not found; install the Xcode command line tools first, or set GIT_BIN to its absolute path'
  exit 1
fi

if [[ ! -e ${DOTFILES_DIR} ]]; then
  if ! "${git_bin}" clone "${DOTFILES_REPO_URL}" "${DOTFILES_DIR}"; then
    print -u2 "failed to clone ${DOTFILES_REPO_URL} into ${DOTFILES_DIR}"
    exit 1
  fi
elif [[ ${DOTFILES_NO_UPDATE} != 1 ]]; then
  # `git pull ${DOTFILES_DIR}` treated the checkout as a *remote* and merged it
  # into whatever repository the caller happened to be standing in. -C makes it
  # an update of the checkout, --ff-only refuses to invent a merge commit in a
  # tree nobody is watching, and a failure stops the run instead of installing
  # from a half-updated tree.
  if ! "${git_bin}" -C "${DOTFILES_DIR}" pull --ff-only; then
    print -u2 "failed to update ${DOTFILES_DIR}; resolve it by hand and rerun"
    exit 1
  fi
fi

# Each source is checked. `source` on a missing or broken file returns nonzero
# and carries on, so an unreadable util.zsh used to leave every later util::
# call undefined and the run limped along printing "command not found" instead
# of saying what was wrong. util::error is not available for the first one, by
# definition.
if ! source "${DOTFILES_DIR}/setup/util.zsh"; then
  print -u2 "cannot load ${DOTFILES_DIR}/setup/util.zsh; is DOTFILES_DIR a checkout of this repo?"
  exit 1
fi

if ! source "${DOTFILES_DIR}/setup/links.zsh"; then
  util::error "cannot load ${DOTFILES_DIR}/setup/links.zsh; is DOTFILES_DIR a checkout of this repo?"
  exit 1
fi

# Before the deploy, not only at uninstall. A machine set up by an older version
# of this repo carries whole-directory links where file-level entries now go,
# and every one of them would make the deploy below write back into this repo
# through the link. Removing them is what makes a rerun converge.
util::info 'clean up links this repo no longer declares...'
if ! links::remove_obsolete; then
  util::error 'some obsolete links could not be removed; resolve them and rerun'
  exit 1
fi

util::info 'deploy dotfiles...'
if ! links::install_all; then
  util::error 'some links could not be deployed; resolve the conflicts above and rerun'
  exit 1
fi

# Sourced, not executed: 00_mise.zsh's activation has to land in the shell the
# later install steps run in. A missing file and a failing step are different
# problems, so the file is checked before it is sourced rather than letting one
# nonzero status stand for both.
if [[ ! -f ${DOTFILES_DIR}/setup/install.zsh ]]; then
  util::error "cannot load ${DOTFILES_DIR}/setup/install.zsh; is DOTFILES_DIR a checkout of this repo?"
  exit 1
fi

if ! . "${DOTFILES_DIR}/setup/install.zsh"; then
  util::error 'setup did not finish; see the messages above'
  exit 1
fi
