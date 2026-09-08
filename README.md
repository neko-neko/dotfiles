[![CI](https://github.com/neko-neko/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/neko-neko/dotfiles/actions/workflows/ci.yml)

# My dotfiles
my dotfiles

# Installation
1. Install XCode CLI tools, run this.
    ```terminal
    sudo xcode-select --switch /Library/Developer/CommandLineTools
    xcode-select --install
    ```

2. Install my dot files:
    ```terminal
    zsh -c "$(curl -s https://raw.githubusercontent.com/neko-neko/dotfiles/master/setup/setup.zsh)"
    ```
    This deploys the symlinks, installs the shared development baseline
    `Brewfile` and runs the scripts under `setup/install/`, including the
    LazyVim step described below. It asks before each part; nothing answers the
    prompts on your behalf.

    To run it against a checkout you already have, point it at that tree and
    tell it not to update:
    ```terminal
    DOTFILES_DIR=$PWD DOTFILES_NO_UPDATE=1 ./setup/setup.zsh
    ```
    That is how CI exercises the commit it just checked out. With no checkout,
    `setup.zsh` clones into `$DOTFILES_DIR` (`~/.dotfiles` by default) and, on a
    rerun, updates it with `git -C <repo> pull --ff-only`. A failed clone or
    update stops the run rather than installing from a tree in an unknown state.

3. Install the layers for this machine:
    ```terminal
    ./setup/layer.zsh                              # list the available layers
    ./setup/layer.zsh mac-client                   # personal Mac workstation
    ./setup/layer.zsh hermes-server                # headless dev/build server
    ./setup/layer.zsh hermes-server home-network   # dev/build server also serving the home LAN
    ```

# Layer composition
Three scopes, installed in this order:

```
Brewfile                     shared development baseline, installed by bootstrap
  └── machine-role layer     hermes-server | mac-client   (pick one)
        └── service overlay  home-network                 (optional)
```

| layer | scope | what it adds |
|---|---|---|
| `hermes-server` | machine role | Tailscale, the ffmpeg media runtime Hermes' voice path needs, headless reverse-engineering tooling, the Godot game engine, and a separately-confirmed Hermes Agent configuration hook ([`hermes/README.md`](hermes/README.md)) |
| `mac-client` | machine role | GUI casks, fonts, App Store apps, mobile SDKs, and a separately-confirmed macOS defaults hook (key repeat, Dock, Finder) |
| `home-network` | service overlay | AdGuard Home, Syncthing, Jellyfin |

`hermes-server` is the always-on headless box that *runs* AI agents. The agent
tooling every machine gets — `agent-browser`, `googleworkspace-cli`, tmux,
ripgrep, jq, uv — is baseline, because `setup/install/15_agent_skills.zsh`
installs the skills that need it during bootstrap, before a layer is picked.
Node is not on that list: it is a language runtime, and those come from mise
(see "Language runtimes" below).
What the layer adds is what only the server exercises. `ffmpeg` is the clearest
case: Hermes lists it as a required non-Python runtime, and Edge TTS, local
Whisper STT and Discord voice bubbles all transcode through it. `godot` is here
for the same reason: game development runs on this box, and the cask's binary
works without a display (`godot --headless`), so project export, script
execution and batch runs need no workstation.

`mac-client` is curated rather than mirrored. An app earns a line when the
tracked configuration needs it; software installed by hand for a one-off or a
hobby is left out of the manifest on purpose.

Supported compositions:

| machine | install |
|---|---|
| headless Tailscale dev/build server | baseline + `hermes-server` |
| personal Mac workstation | baseline + `mac-client` |
| dev/build server that also serves the home LAN | baseline + `hermes-server` + `home-network` |

`home-network` is an overlay, not a machine role. It is normally composed with
`hermes-server`, which is where `tailscale` is declared. Whether it works on its
own, or on top of `mac-client`, is untested rather than supported.

Rules:

- A package belongs in the baseline `Brewfile` when it is part of the shared
  development toolchain, and in a layer when it is specific to one machine role
  or overlay. Formula vs cask is a packaging detail, not a scope signal.
- A global language runtime belongs in no `Brewfile` at all. See "Language
  runtimes" below.
- Anything a `bin/` script, a `config/` file or a `setup/install/` step invokes
  is baseline by construction. Bootstrap deploys all three on every machine
  before a layer is chosen, so a command they call has to be declared where
  bootstrap installs from.
- `setup/layer.zsh` installs the layers you name in the table order above,
  whatever order you pass them in. Package installs go through `BREW_BIN`, an
  overridable absolute path, so a test can pin the binary that runs instead of
  trusting PATH. The baseline installer has the same seam.
- A layer may ship a `configure.zsh` next to its `Brewfile`. `setup/layer.zsh`
  discovers it and asks a second time, separately from the package
  confirmation, because applying settings to a machine is a different decision
  from installing its binaries. Both machine-role layers have one:
  `hermes-server` applies the Hermes Agent desired state, `mac-client` applies
  the macOS defaults. `home-network` is packages only.
- A failure stops the run. A layer whose `Brewfile` or hook failed does not
  print as complete, and the layers listed after it are not installed. The same
  rule holds in `setup/install.zsh`: a failed baseline `Brewfile` runs no steps,
  and a step that fails stops the ones after it. Declining a confirmation is a
  choice, not a failure, and the run carries on.
- A package belongs in a manifest, not in a setup step. No step under
  `setup/install/` calls Homebrew, so nothing a `brew bundle` could have
  declared is installed behind the Brewfiles' back. Two steps still fetch
  software Homebrew does not publish: `14_slackcli.zsh` downloads a release
  binary into `~/.local/bin`, and `12_krew.zsh` installs kubectl plugins
  through krew. Neither has a formula or a cask to declare.
- The same tool may appear in two layers when each role needs a different build
  of it (`ghidra` is a headless formula in `hermes-server` and a GUI cask in
  `mac-client`). That pair is an explicit allowlist, not a general licence: any
  other cross-layer duplicate fails the spec. A package must never appear in
  both the baseline `Brewfile` and a layer. `spec/brewfile_spec.sh` enforces
  this, along with tap declarations, the layer registry, and the placement of
  the packages a role cannot work without.

# What gets deployed
`setup/links.zsh` is the registry of every symlink this repo creates, and the
only code that creates or removes one. `setup/setup.zsh` deploys from it and
`setup/uninstall.zsh` removes from it, so the two halves cannot drift apart.

Entries are enumerated, never globbed. The deployer this replaced linked every
top-level entry that was not on a deny list, which is how `~/.Brewfile`,
`~/.CLAUDE.md` and `~/.spec` came to exist: three files that are repository
machinery and mean nothing in `$HOME`.

A whole directory is linked only when this repo is its only writer, which today
means `ccstatusline`, `ghostty`, `mise`, `sesh`, `sheldon` and `starship.toml`.
A directory something else writes into gets one entry per tracked file instead,
so the live directory stays real:

| directory | who else writes there |
|---|---|
| `$XDG_CONFIG_HOME/herdr` | herdr keeps sockets, logs, `session.json` and installed plugins in it |
| `$XDG_CONFIG_HOME/karabiner` | Karabiner-Elements writes `automatic_backups/` and rewrites `karabiner.json` in place |

Deployment never destroys anything it cannot prove it owns:

- an absent target, or a symlink already pointing into this repo, is created or
  repointed;
- a real file or directory, or a symlink pointing anywhere else, is left exactly
  as it is and reported as a conflict for you to resolve;
- a real file byte-identical to the repo's copy is the one exception, and it is
  replaced only after `cmp` proves the equality;
- a conflict does not stop the *deploy*: every other entry is still linked, so a
  rerun after you resolve it has only that one entry left to do. It does stop
  the *bootstrap*. `setup/setup.zsh` treats any unresolved conflict as fatal and
  returns before it installs a single package, because a machine whose
  configuration did not land is not a machine to start installing software onto.

Before deploying, `setup/setup.zsh` also removes the links an older version of
this repo created and this one no longer declares, under exactly the same
ownership rule: only symlinks that still resolve into this checkout. That is
what lets a machine set up years ago converge on a rerun instead of failing on a
whole-directory link sitting where a file-level entry now goes.

Uninstall is the mirror image. It removes a symlink only when it resolves to
exactly the source that declared it, leaves real files, real directories and
foreign symlinks alone, and runs the same obsolete-link cleanup the deploy does:
`~/.Brewfile`, `~/.CLAUDE.md`, `~/.spec`, the nested
`~/.config/karabiner/karabiner` that `ln -s` into an existing directory left
behind, and `~/.config/herdr` while it is still a whole-directory link into this
repo. It removes no packages and no runtime directories, and it reports a
nonzero status when any of its three stages could not finish.

"Resolves to" is about the file, not the text. A relative symlink written by
hand and the absolute one this repo writes name the same file, so both are
recognised as this repo's.

# Herdr
`config/herdr/config.toml` is the tracked configuration, symlinked as a single
file into the live `$XDG_CONFIG_HOME/herdr`. It binds keys to plugin actions, so
the plugins those bindings name are part of the configuration too.

`setup/herdr.zsh` is the manifest for them and `setup/install/18_herdr_plugins.zsh`
applies it. The local `drop-upload` plugin lives in this repo and is linked from
it; `herdr-file-viewer` and `hunk.diff` are external and are installed at an
exact commit, so two machines get the same plugin. The step reads the installed
set first and acts only on the difference, so a rerun on a converged machine
issues one read and no writes.

What is *not* tracked is anything herdr generates: `plugins.json`, its own
registry of what it installed, complete with absolute paths from whichever
machine wrote it, and the `plugins/github/` checkouts it made. Both were
committed once and neither survived contact with a second machine.

Ownership is the plugin's root, not its name. Before linking, the step reads
`herdr plugin list --json` and refuses to act when the id it declares is already
held by a plugin linked from another checkout or installed from GitHub, rather
than repointing somebody else's plugin at this tree.

Uninstall unlinks `drop-upload` and stops there, and only after that same read
proves the `drop-upload` herdr currently holds is the one this checkout linked.
A plugin that is not there at all is a success, not an error. The external
plugins are yours, and this repo does not get to decide they are disposable.

# Language runtimes
`config/mise/config.toml` is the single registry for every global language
runtime: Java, Node, Python, Rust, Ruby, Flutter, Go, Deno, Lua, Bun, and the
`shellcheck` this repo lints with. No `Brewfile` declares any of them.

The reason is that Homebrew installs one version per formula. A runtime declared
in both places gives a machine two copies, and which one answers `node` becomes
an accident of PATH order rather than a decision anyone wrote down. The same
argument removed FVM: a second Flutter version manager alongside mise's
`flutter` is that conflict with extra steps.

`brew 'mise'` stays in the baseline `Brewfile`, because the thing that installs
runtimes cannot itself be one of them.

Bootstrap ordering falls out of this. `setup/install/00_mise.zsh` runs first,
installs everything in the registry, and puts the shims on PATH for the rest of
the run — `setup/install.zsh` sources each step, so the activation reaches the
later ones. `15_agent_skills.zsh` calls `npx`, and that is where its Node comes
from. `~/.zshenv` runs the same activation for every shell afterwards, and it is
the only PATH entry that provides a global runtime.

`spec/brewfile_spec.sh` pins the boundary from both sides: no runtime in any
manifest, every runtime in `[tools]`, and no competing version manager. The
installer's ordering, its `MISE_BIN` seam and its failure paths are covered by
`spec/mise_spec.sh` against a stub, so the suite never installs anything.

Per-project versions are unaffected. `idiomatic_version_file_enable_tools` keeps
mise reading `.ruby-version`, `.python-version`, `.go-version` and `.nvmrc`.

# Neovim / LazyVim
`setup/install/16_lazyvim.zsh` sets up `$XDG_CONFIG_HOME/nvim` (`~/.config/nvim`
by default). It is rerunnable and never deletes or overwrites an existing config.

- **Fresh machine.** Clones [LazyVim/starter](https://github.com/LazyVim/starter)
  and removes the clone's `.git`, so the config starts as your own plain files
  instead of a checkout of the starter. Plugins install on the first `nvim` launch.
- **`~/.config/nvim` already exists.** Left untouched, whether it is a populated
  directory, a symlink, or a file. If it is still a clone of `LazyVim/starter`,
  the installer prints the command to detach it and does nothing else.
- **Empty directory.** Treated as a fresh machine and populated in place.

The nvim config is deliberately not symlinked out of this repo the way
`config/*` is: LazyVim writes `lazy-lock.json` and `lazyvim.json` into it, so it
has to be a writable directory the user owns.

# Hermes Agent
`hermes/` holds the tracked desired state for Hermes Agent: a set of non-secret
settings and the canonical `SOUL.md`. `hermes/configure.zsh` applies them to
`$HERMES_HOME` through `hermes config set` and verifies each write by reading it
back. It is the `hermes-server` layer's configure hook, and it can also be run
on its own.

`$HERMES_HOME` (`~/.hermes`) is never symlinked into this repo and never
committed. Secrets, auth, sessions, memories, logs and gateway runtime state
stay there and are not managed here. Nothing in `setup/links.zsh` names `hermes`
as a source or `~/.hermes` as a target, and because that registry is an allow
list rather than a deny list, this repo cannot land on top of that tree by
default.

Restarting the gateway is not part of applying: the script prints the command
and stops. See [`hermes/README.md`](hermes/README.md) for the full boundary, the
managed key list, and the SOUL migration cases.

# Uninstallation
1. run this:
    ```terminal
    cd ~/.dotfiles && ./setup/uninstall.zsh
    ```
    This removes the symlinks it created, and only those: see "What gets
    deployed" above for the exact rule. `~/.config/nvim` is left alone, since
    the LazyVim step hands it over to you rather than managing it, and so are
    the live `herdr` and `karabiner` config directories. No packages are
    uninstalled.
