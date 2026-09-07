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
    LazyVim step described below.

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
| `mac-client` | machine role | GUI casks, fonts, App Store apps, mobile SDKs |
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
  trusting PATH.
- A layer may ship a `configure.zsh` next to its `Brewfile`. `setup/layer.zsh`
  discovers it and asks a second time, separately from the package
  confirmation, because applying settings to a service is a different decision
  from installing its binaries. Only `hermes-server` has one today.
- The same tool may appear in two layers when each role needs a different build
  of it (`ghidra` is a headless formula in `hermes-server` and a GUI cask in
  `mac-client`). That pair is an explicit allowlist, not a general licence: any
  other cross-layer duplicate fails the spec. A package must never appear in
  both the baseline `Brewfile` and a layer. `spec/brewfile_spec.sh` enforces
  this, along with tap declarations, the layer registry, and the placement of
  the packages a role cannot work without.

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
stay there and are not managed here. `setup/setup.zsh` deliberately excludes
`hermes` from the directories it deploys as `~/.<name>`, so this repo cannot
land on top of that tree.

Restarting the gateway is not part of applying: the script prints the command
and stops. See [`hermes/README.md`](hermes/README.md) for the full boundary, the
managed key list, and the SOUL migration cases.

# Uninstallation
1. run this:
    ```terminal
    cd ~/.dotfiles && ./setup/uninstall.zsh
    ```
    This removes the symlinks it created. `~/.config/nvim` is left alone, since
    the LazyVim step hands it over to you rather than managing it.
