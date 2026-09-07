# ------------------------------
# Baseline Brewfile
# ------------------------------
# The shared development baseline, installed by bootstrap (setup/setup.zsh ->
# setup/install.zsh) on every box this repo sets up.
#
# Scope rule: a package belongs here when it is part of that development
# baseline, and in a layer under setup/layers/<name>/ when it is specific to one
# machine role or service overlay. Formula vs cask is a packaging detail, not a
# scope signal: `codex`, `gcloud-cli` and `1password-cli` ship as casks but are
# baseline CLIs, so they live here.
#
# The other thing that makes a package baseline is being reachable from
# something bootstrap deploys everywhere: a script under `bin/`, a file under
# `config/`, or a step in `setup/install/`. Those land on every machine before a
# layer is chosen, so the commands they invoke have to be declared here.
#
# Language runtimes are the one exception, and they are not declared in any
# Brewfile. `config/mise/config.toml` is their single registry, and
# `setup/install/00_mise.zsh` makes them available early enough for the rest of
# bootstrap to use them.
#
# Layers are installed afterwards with `./setup/layer.zsh <layer>...`; see
# README.md "Layer composition" for the supported compositions.

tap 'boz/repo'
tap 'derailed/k9s'
tap 'getsentry/tools'
tap 'hashicorp/tap'
tap 'jesseduffield/lazydocker'
tap 'johanhaleby/kubetail'
tap 'ktr0731/evans'
tap 'schpet/tap'
tap 'rjyo/moshi'

# Taps for tools
brew 'boz/repo/kail'
brew 'derailed/k9s/k9s'
brew 'getsentry/tools/sentry-wizard'
brew 'golangci-lint'
brew 'hashicorp/tap/terraform-ls'
brew 'jesseduffield/lazydocker/lazydocker'
brew 'johanhaleby/kubetail/kubetail'
brew 'ktr0731/evans/evans'
brew 'schpet/tap/linear'
brew 'gum'

# GNU & Utilities
brew 'autoconf'
brew 'binutils'
brew 'cairo'
brew 'cmake'
brew 'coreutils'
brew 'curl'
brew 'diffutils'
brew 'findutils'
brew 'gawk'
brew 'gcc'
brew 'gettext'
brew 'giflib'
brew 'gmp'
brew 'gnu-indent'
brew 'gnu-sed'
brew 'gnu-tar'
brew 'gnu-which'
brew 'gnupg'
brew 'gnutls'
brew 'grep'
brew 'imagemagick'
brew 'jpeg'
brew 'lhasa'
brew 'libpng'
brew 'libpq'
brew 'librsvg'
brew 'libyaml'
brew 'make'
brew 'nkf'
brew 'openssl@3'
brew 'pango'
brew 'pixman'
brew 'pkgconf'
brew 'source-highlight'
brew 'tree'
brew 'vips'
brew 'wget'

# Shell & Terminal
brew 'ast-grep'
brew 'direnv'
brew 'fzf'
brew 'sheldon'
brew 'starship'
brew 'zoxide'
brew 'herdr'
brew 'hunk'
brew 'rjyo/moshi/moshi-hook'
brew 'mosh'
# `bin/tmux-session-name` and `config/sesh/sesh.toml` are deployed on every
# machine, and hermes/SOUL.md dispatches coding agents through tmux sessions.
brew 'tmux'
brew 'sesh'

# Editors
brew 'neovim'

# Git & Version Control
brew 'diff-so-fancy'
brew 'gh'
brew 'ghq'
brew 'gibo'
brew 'git'
brew 'git-delta'
brew 'git-lfs'
brew 'lazygit'
brew 'worktrunk'

# Cloud & DevOps
brew 'argocd'
brew 'awscli'
brew 'azure-cli'
brew 'cloudflared'
brew 'docker', link: false
brew 'hadolint'
brew 'helm'
brew 'heroku'
brew 'istioctl'
brew 'krew'
brew 'kubernetes-cli'
brew 'kubectx'
brew 'kubeseal'
brew 'sops'
brew 'tflint'
cask 'gcloud-cli'

# Toolchain
# Language runtimes are NOT declared here. `config/mise/config.toml` is their
# single registry, and `setup/install/00_mise.zsh` installs them and puts the
# shims on PATH before the rest of bootstrap runs. What stays is the version
# manager itself plus the package managers, schema compilers and client
# libraries that are not a runtime anyone switches versions of.
brew 'mise'
brew 'mysql-client'
brew 'protobuf'
brew 'uv'

# AI Tools
brew 'gemini-cli'
cask 'codex' # OpenAI Codex CLI agent (terminal tool, not a GUI app)
# Runtimes for the agent skills `setup/install/15_agent_skills.zsh` installs on
# every machine: `agent-browser` backs the vercel-labs browser skill (and is the
# `browser` dependency Hermes' hermes_cli/dep_ensure.py probes for), and
# `googleworkspace-cli` provides the `gws` binary the five gws-* skills declare
# under `requires.bins`.
brew 'agent-browser'
brew 'googleworkspace-cli'

# LSPs
brew 'bash-language-server'
brew 'dockerfile-language-server'
brew 'yaml-language-server'

# Alternatives to classic CLI
brew 'bat' # cat
brew 'bottom' # top
brew 'fx' # jq viewer
brew 'jq'
brew 'q' # dig
brew 'ripgrep' # grep
brew 'tldr' # man

# 1Password
cask '1password-cli'

# Testing
# This repo's own test runner. `.shellspec` and `spec/` are useless without it,
# and CI had to `brew install shellspec` by hand because it was declared nowhere.
brew 'shellspec'

# Other
brew 'grip'
brew 'nmap'
