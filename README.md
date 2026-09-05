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
| `hermes-server` | machine role | Tailscale, headless reverse-engineering tooling |
| `mac-client` | machine role | GUI casks, fonts, App Store apps, mobile SDKs |
| `home-network` | service overlay | AdGuard Home, Syncthing, Jellyfin |

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
- `setup/layer.zsh` installs the layers you name in the table order above,
  whatever order you pass them in.
- The same tool may appear in two layers when each role needs a different build
  of it (`ghidra` is a headless formula in `hermes-server` and a GUI cask in
  `mac-client`). A package must never appear in both the baseline `Brewfile` and
  a layer. `spec/brewfile_spec.sh` enforces this, along with tap declarations
  and the layer registry.

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

# Uninstallation
1. run this:
    ```terminal
    cd ~/.dotfiles && ./setup/uninstall.zsh
    ```
    This removes the symlinks it created. `~/.config/nvim` is left alone, since
    the LazyVim step hands it over to you rather than managing it.
