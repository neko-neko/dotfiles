[![CI](https://github.com/neko-neko/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/neko-neko/dotfiles/actions/workflows/ci.yml)

# My dotfiles
my dotfiles

# Installation
This repo is a flake-based, per-host [nix-darwin](https://github.com/nix-darwin/nix-darwin)
configuration (`flake.nix` / `nix/`). Nix is the install/management path
for packages, macOS defaults, and dotfile deployment — there is no
Brewfile or setup script to run instead.

1. Install XCode CLI tools:
    ```terminal
    sudo xcode-select --switch /Library/Developer/CommandLineTools
    xcode-select --install
    ```

2. Install Nix ([Determinate Nix installer](https://determinate.systems/)):
    ```terminal
    curl -fsSL https://install.determinate.systems/nix | sh -s -- install macos
    ```

3. Clone this repo and replace the placeholder username in
   `nix/hosts/<hostname>/default.nix` with the real macOS short username
   (`whoami`) on the target machine — see `docs/nix-migration.md` before
   you build/switch for the first time.

4. Build and switch the host matching this machine's role:
    ```terminal
    sudo darwin-rebuild switch --flake .#mac-client      # personal Mac client
    sudo darwin-rebuild switch --flake .#hermes-server   # Tailscale Hermes server
    sudo darwin-rebuild switch --flake .#home-network    # Jellyfin/media/home-network box
    ```

See `docs/nix-migration.md` for the full runbook — build/check without
applying, order of operations across hosts, and rollback.

# Uninstallation
```terminal
sudo darwin-rebuild rollback
```
This reverts the Nix-managed system generation (packages, macOS defaults,
dotfiles, the nix-homebrew wiring). It does not touch Homebrew package
state — see `docs/nix-migration.md` "Rollback" for what that does and
doesn't undo.

# VSCode / Cursor
VSCode and Cursor installation and extension management are **no longer
handled by this repo** (the `cursor` cask and the Cursor extension list
have been removed, and nothing under `nix/` declares `homebrew.vscode` or
a `cursor` cask). Manage your editor and its extensions outside of
dotfiles.

# Nix migration status
See `docs/nix-migration.md` for what's implemented per host, the
build/check/apply/rollback commands, and known risks (most hosts have not
had a real `darwin-rebuild switch` run against them yet — see that doc's
"Known risks" before touching `hermes-server` or `home-network`).

Every responsibility the old `setup/` scripts had — package install,
dotfile deployment, macOS defaults, kubectl-krew plugins, Helix grammars,
`slackcli`, and Claude agent skills sync — is covered by this flake; see
`docs/nix-migration.md` "Former setup script coverage" for the full
script-by-script mapping.
