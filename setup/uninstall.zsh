#!/bin/zsh
# Removes what setup/links.zsh deployed, and nothing else.
#
# The hand-maintained list this replaced had drifted badly in both directions.
# It named six paths this repo no longer ships (ctags.d, git_template,
# gitmessage, tigrc, tmux.conf, an iTerm2 plist) and missed most of what the
# deployer actually created, and it called `unlink` unconditionally, so a real
# file a human had put at one of those paths was removed without a word.
# Consuming the same registry the deployer uses is what keeps the two halves
# from drifting again.

: ${DOTFILES_DIR:=${0:A:h:h}}

# Each source is checked, before the prompt and before anything is removed.
# `source` on a missing or broken file returns nonzero and carries on, so an
# unreadable links.zsh used to leave links::uninstall_all undefined: the run
# printed "command not found", counted that as a failed stage, and reported that
# things could not be removed without ever saying the module had not loaded. An
# unreadable herdr.zsh was worse, because the two link stages ran first and the
# machine was half cleaned by the time it showed. util::error is not available
# for the first one, by definition.
if ! source "${DOTFILES_DIR}/setup/util.zsh"; then
  print -u2 "cannot load ${DOTFILES_DIR}/setup/util.zsh; nothing was removed"
  exit 1
fi

for module in links herdr; do
  if ! source "${DOTFILES_DIR}/setup/${module}.zsh"; then
    util::error "cannot load ${DOTFILES_DIR}/setup/${module}.zsh; nothing was removed"
    exit 1
  fi
done

util::confirm 'remove the dotfiles symlinks?'
if [[ $? != 0 ]]; then
  util::info 'nothing removed'
  exit 0
fi

# Every stage runs, and every stage's failure survives to the exit status. Each
# one is convergent on its own, so stopping at the first would leave links this
# repo owns behind for no reason. Printing "done" over a failure was worse: the
# only report a human got said the machine was clean when it was not.
failed=0
links::uninstall_all   || failed=1
links::remove_obsolete || failed=1
herdr::unlink_local    || failed=1

if (( failed )); then
  util::error 'some things could not be removed; see the messages above'
  exit 1
fi

util::info 'done. no packages were removed and no runtime directories were touched.'
