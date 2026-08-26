# Nix migration runbook

Status: **structure only, not yet applied anywhere.** Nothing under
`flake.nix` / `nix/` has been built, checked, or activated on a real
machine — see `COMMANDS_RUN` in this PR's report for exactly what *was*
verified without a local Nix install. The existing Brewfile/`setup.zsh`
flow is unaffected and remains the default install path.

Background: `/tmp/dotfiles-nix-architect-report.md` (recommendation) and
`/tmp/dotfiles-nix-reviewer-report.md` (skeptical review, verdict YELLOW —
narrow scope, no big-bang cutover) are the two prior investigations this
migration is built on. Read them before changing scope.

## What's here

```
flake.nix                          inputs: nixpkgs, nix-darwin, home-manager, nix-homebrew
nix/modules/common.nix             nix settings, state versions, nix-homebrew wiring
nix/modules/packages-common.nix    conservative home.packages CLI list (all 3 hosts)
nix/modules/macos-defaults.nix     29_macos.zsh translated to system.defaults.* (mac-client only)
nix/modules/homebrew-bridge-common.nix   everything from the root Brewfile NOT moved to Nix
nix/hosts/mac-client/default.nix   Phase 1–3 target: GUI/mobile-dev Mac, no VSCode/Cursor
nix/hosts/hermes-server/default.nix     Phase 4 target: headless Tailscale box
nix/hosts/home-network/default.nix      Phase 5 target: Jellyfin/AdGuard/Syncthing Mac mini
```

Phase numbering follows the architect report §4:
Phase 1 (flake skeleton) + Phase 2 (CLI → Nix) + Phase 3 (Homebrew bridge
for mac-client) are represented together in `nix/hosts/mac-client/`. Phase
4 (hermes-server) and Phase 5 (home-network) each get their own host file.
None of them have been applied — "represented" means the declarative
config exists and is structured for a safe, staged rollout, not that any
host has been switched over.

## Before you build anything: fix the placeholder username

Every host file sets:

```nix
system.primaryUser = "neko";
users.users.neko = { name = "neko"; home = "/Users/neko"; };
```

`"neko"` is a placeholder so the flake evaluates for anyone who clones
this repo. **Replace it with the real macOS short username (`whoami`) on
the target machine** before running `build` or `switch` for that host.
Getting this wrong doesn't corrupt anything — nix-darwin will just try to
manage the wrong user's Homebrew/home-manager profile — but fix it first
so `darwin-rebuild switch` doesn't silently do nothing useful.

## Install Nix (do not run yet — this is what the runbook documents, not what this PR executes)

Determinate Nix installer, macOS:

```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install macos
```

Uninstall, if you ever need to back all the way out:

```sh
sudo /nix/nix-installer uninstall
```

Upgrade an existing Determinate Nix install:

```sh
sudo determinate-nixd upgrade
```

## Build / check each host

These only evaluate and build the Nix closure into the local Nix store —
they do **not** touch Homebrew, macOS defaults, or anything outside
`/nix`. Safe to run repeatedly.

```sh
nix flake check                                  # evaluate all outputs
nix build .#darwinConfigurations.mac-client.system      --dry-run
nix build .#darwinConfigurations.hermes-server.system   --dry-run
nix build .#darwinConfigurations.home-network.system    --dry-run
```

Drop `--dry-run` once you want to actually build (still doesn't apply
anything to the running system — `darwin-rebuild switch` is the only
command that does).

## Apply — after manual approval only

Do this only on the specific host being migrated, after reading the risks
below, and never on `hermes-server` or `home-network` before it has been
rehearsed on `mac-client` first (see "Order of operations").

```sh
sudo darwin-rebuild switch --flake .#<hostname>
```

First activation additionally runs `nix-homebrew`'s Homebrew migration
(`autoMigrate = true`), which takes 2–5 minutes and re-links your existing
Homebrew Cellar/Caskroom/taps under Nix's management without reinstalling
anything.

## Order of operations

1. `mac-client` first. It's the only host with a human present to notice
   and undo a problem immediately, and it's the only host with GUI/mas
   packages to validate the Homebrew bridge against.
2. `hermes-server` only after `mac-client` has run stably for a while and
   at least one `darwin-rebuild rollback` has been rehearsed successfully.
   It's remote and headless — a broken activation there costs an SSH trip
   to fix, or worse if SSH itself breaks.
3. `home-network` last, and only after a maintenance window is arranged.
   It runs Jellyfin/AdGuard/Syncthing for people other than the repo
   owner; a failed activation has real, immediate impact on them.

## Rollback

```sh
sudo darwin-rebuild rollback
```

This atomically reverts the Nix-managed system generation (packages,
`system.defaults`, the nix-homebrew wiring). **It does not touch Homebrew
package state** — installed casks/formulae stay installed, and anything
`onActivation.cleanup` would have removed on the way in only gets removed
on the way in, not restored on the way back. This is exactly why
`homebrew.onActivation.cleanup` stays `"none"` in
`nix/modules/homebrew-bridge-common.nix`: with cleanup set to
`"uninstall"`/`"zap"`, a rollback still leaves you with whatever got
uninstalled during the failed forward activation. Do not change that
setting until declared state and real `brew bundle dump` state have been
diffed and confirmed to match.

At the repo level, every phase is a normal commit — reverting the commit
that introduced a host's Nix config is always available as a fallback
independent of `darwin-rebuild rollback`.

## Known risks

- **PATH collision.** Once a host is on Nix, both `/opt/homebrew/bin` and
  the Nix profile's `bin` will contain some of the same binaries (e.g.
  anything still in both `packages-common.nix` and a Brewfile prior to
  full cutover — see "Expanding the Nix-native package list" below for
  why the two lists are currently disjoint by design). Decide and
  document PATH order (Nix profile vs. Homebrew) in `zshenv` **before**
  activating any host; this repo does not yet make that choice for you.
- **`nix-homebrew.autoMigrate` is real-machine-dependent and untested by
  this PR.** It has only been evaluated against docs (Context7), never
  run. Rehearse on `mac-client` first, not on `hermes-server` or
  `home-network`.
- **GUI/MAS apps stay Homebrew-managed on purpose.** nix-darwin's
  `homebrew.*` module only generates a Brewfile and calls `brew bundle` —
  it does not replace Homebrew, and `masApps` still requires being signed
  into the Mac App Store or `mas` install fails (confirmed via Context7,
  see architect report §6). No amount of Nix wrapping fixes that.
- **Secrets are not in this tree, and must stay that way.** The Nix store
  (`/nix/store`) is world-readable on a multi-user system. Nothing here
  reads `op`/1Password state or writes secrets into a Nix expression —
  keep it that way; if a future host config needs a secret, it needs
  sops-nix/agenix first, not a literal value in a `.nix` file.
- **`adguardhome`/`syncthing` stay Homebrew-managed, not launchd-native,**
  because nix-darwin has no first-class services module for either
  (confirmed absent via Context7, unlike NixOS's `services.syncthing`).
  Hand-rolling `launchd.daemons` units for a family-used production media
  box without a rehearsal environment is out of scope for this PR.
- **`nix flake check` has not actually been run.** No `nix` binary was
  available in the environment this PR was written in. Every option name
  used here was cross-checked against nix-darwin/home-manager/nix-homebrew
  documentation via Context7 (see PR report for the specific facts and
  sources), and the `.nix` files were checked for balanced
  braces/brackets/quotes, but neither is a substitute for a real
  evaluation. The CI job below is non-blocking (`continue-on-error: true`)
  for exactly this reason — flip it to blocking once the first real run
  is green.

## mise vs Nix

`mise` keeps owning **per-repository language runtime versions**. Nix
here owns **machine-wide CLI tooling** (`nix/modules/packages-common.nix`)
and the **Homebrew bridge** (everything else). Do not add a language
runtime (node, python, ruby, go, ...) to `home.packages` anywhere in this
tree — that recreates the exact "which one is authoritative" problem the
architect report flagged as a reason full migration isn't attractive.

## Expanding the Nix-native package list

`nix/modules/packages-common.nix` intentionally moved only ~20
unambiguous, well-known nixpkgs packages out of the root Brewfile. Before
adding another package to that list:

1. Confirm the exact nixpkgs attribute name on a machine with Nix
   installed: `nix search nixpkgs <name>`. Brew formula names and nixpkgs
   attribute names frequently differ (e.g. Homebrew's `kubernetes-cli` is
   nixpkgs' `kubectl`; Homebrew's `awscli` is nixpkgs' `awscli2`) — this
   is exactly why those two stayed in the Homebrew bridge instead of being
   guessed at here.
2. Remove the corresponding line from the relevant Brewfile(s) so the
   package isn't declared through two package managers at once (see "PATH
   collision" above).
3. Verify the binary actually resolves to the Nix-built one after
   activation (`which <binary>`), not a stale Homebrew shim.

## CI

`.github/workflows/ci.yml` gained one job, `nix-flake-check`, which
installs Nix on a GitHub-hosted `macos-latest` runner (via
`cachix/install-nix-action`) and runs `nix flake check`. It does not run
`darwin-rebuild switch` or otherwise mutate anything outside the runner.
This job is required to pass before this PR is considered mergeable; if it
fails, fix the Nix option/package mismatch it surfaces rather than treating
local heuristic checks as sufficient.

The two existing jobs (`test`: `CI=true ./setup/setup.zsh`; `shellspec`)
are unchanged and continue to be the source of truth for the
non-Nix install path.

## VSCode/Cursor removal

VSCode/Cursor installation and extension management are discontinued in
this repo as of this migration:

- `cask 'cursor'` and the "Cursor Extensions" `vscode '...'` block (62
  entries) are removed from `setup/layers/mac-client/Brewfile`.
- The `vscode/` directory (`vscode/settings.json`, which only ever
  supported the VSCode/Cursor `User/settings.json` symlink) and its
  deploy step in `setup/setup.zsh` are removed.
- Nothing in `nix/` declares `homebrew.vscode` (the nix-darwin option that
  would reintroduce extension management) — this is deliberate, not an
  oversight.
- If VSCode/Cursor support returns in the future, it needs a fresh design
  decision, not a revert of this removal — extension lists rot quickly and
  the ones removed here were not re-validated.
