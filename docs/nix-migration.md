# Nix migration runbook

Status: **Nix is the dotfiles install/management path.** There is no
Brewfile or `setup.zsh` flow anymore — packages, macOS defaults, and
dotfile deployment are all declared under `flake.nix` / `nix/`. That said,
nothing under `flake.nix` / `nix/` has actually been built, checked, or
activated on a real machine yet — see `COMMANDS_RUN` in this PR's report
for exactly what *was* verified without a local Nix install. Run `nix
flake check` and a `--dry-run` build (see below) before the first real
`darwin-rebuild switch` on any host.

Background: `/tmp/dotfiles-nix-architect-report.md` (recommendation) and
`/tmp/dotfiles-nix-reviewer-report.md` (skeptical review, verdict YELLOW —
narrow scope, no big-bang cutover) are the two prior investigations this
migration is built on. Read them before changing scope.

## What's here

```
flake.nix                          inputs: nixpkgs, nix-darwin, home-manager, nix-homebrew
nix/modules/common.nix             nix settings, state versions, nix-homebrew wiring
nix/modules/packages-common.nix    conservative home.packages CLI list (all 3 hosts)
nix/modules/macos-defaults.nix     former setup/install/29_macos.zsh, as system.defaults.* (mac-client only)
nix/modules/homebrew-bridge-common.nix   everything from the former root Brewfile NOT moved to Nix
nix/modules/dotfiles-common.nix    root dotfiles + config/* deployed via home.file/xdg.configFile (all 3 hosts)
nix/hosts/mac-client/default.nix   Phase 1–3 target: GUI/mobile-dev Mac, no VSCode/Cursor
nix/hosts/hermes-server/default.nix     Phase 4 target: headless Tailscale box
nix/hosts/home-network/default.nix      Phase 5 target: Jellyfin/AdGuard/Syncthing Mac mini
nix/modules/setup-tasks-common.nix      former setup/install/{12_krew,13_helix,14_slackcli,15_agent_skills}.zsh, as home.activation hooks + home.file (all 3 hosts)
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

## Install Nix

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
  anything still declared in both `packages-common.nix` and
  `homebrew-bridge-common.nix`/a host's `homebrew.brews` — see "Expanding
  the Nix-native package list" below for why the Nix-native and Homebrew
  bridge lists are currently disjoint by design). Decide and document PATH
  order (Nix profile vs. Homebrew) in `zshenv` **before** activating any
  host; this repo does not yet make that choice for you.
- **`nix-homebrew.autoMigrate` is real-machine-dependent and untested by
  this PR.** It has only been evaluated against docs (Context7), never
  run. Rehearse on `mac-client` first, not on `hermes-server` or
  `home-network`.
- **GUI/MAS apps stay Homebrew-managed on purpose.** nix-darwin's
  `homebrew.*` module only generates a Brewfile and calls `brew bundle` —
  it does not replace Homebrew, and `masApps` still requires being signed
  into the Mac App Store or `mas` install fails (confirmed via Context7,
  see architect report §6). No amount of Nix wrapping fixes that.
- **First activation will touch existing dotfiles.** `home-manager.backupFileExtension = "hm-bak"` (see `nix/modules/common.nix`) means an existing real file at a path `nix/modules/dotfiles-common.nix` manages (e.g. an already-present `~/.zshrc` from a pre-Nix machine) gets renamed to `<path>.hm-bak` rather than silently overwritten on first `switch` — but it does mean every path listed there changes on activation. Diff `dotfiles-common.nix`'s file list against what actually exists on the target machine before the first switch if that matters.
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
- **`setup-tasks-common.nix`'s `home.activation` hooks run network calls
  (GitHub API, `npx` registry, `kubectl krew`) on every
  `darwin-rebuild switch`/`home-manager switch`, not just the first one.**
  They're best-effort and guarded (see "Former setup script coverage"
  above), so a flaky network only delays activation slightly and logs a
  warning — it does not fail the switch or leave the system in a partial
  state. Still, this is new behavior versus the pre-migration scripts
  (which only ran once, on demand, when a human invoked `setup/install.zsh`
  interactively) — activation is no longer purely local/offline on hosts
  where these hooks apply.
- **`nix flake check` has not actually been run locally.** No `nix` binary
  was available in the environment this repo was migrated in. Every option
  name used here was cross-checked against
  nix-darwin/home-manager/nix-homebrew documentation via Context7 (see PR
  report for the specific facts and sources), and the `.nix` files were
  checked for balanced braces/brackets/quotes, but neither is a substitute
  for a real evaluation. `nix-flake-check` in CI (see "CI" below) is the
  first real evaluation and is required/blocking — treat its result as
  authoritative over the local heuristic checks, not the other way
  around.

## Former setup script coverage

Every script under the old `setup/` tree is gone (deleted across `8d31051`
and `ddfebf0`). This table maps each one's responsibility to where it now
lives, so nothing that script did is silently unaccounted for:

| Former script | Responsibility | Now covered by |
|---|---|---|
| `setup/setup.zsh` | clone/pull `~/.dotfiles` | **Not migrated, by design.** Manual `git clone`/`git pull` per the README "Installation" steps — a one-time bootstrap action, not an ongoing declarative concern. |
| `setup/setup.zsh` | symlink root dotfiles + `config/*` into `$HOME`/`$XDG_CONFIG_HOME` | `nix/modules/dotfiles-common.nix` (`home.file`/`xdg.configFile`) |
| `setup/install.zsh` | `brew bundle --file Brewfile` | `nix/modules/packages-common.nix` (Nix-native) + `nix/modules/homebrew-bridge-common.nix` + each host's `homebrew.brews`/`homebrew.casks` (Homebrew bridge) |
| `setup/install.zsh` | run every `setup/install/*.zsh` in turn | Replaced 1:1 below — no generic "run every script in a directory" step exists in Nix; each former script maps to a specific module/host entry instead. |
| `setup/install.zsh` | `brew cleanup` | **Not migrated, by design.** `nix/modules/homebrew-bridge-common.nix` keeps `homebrew.onActivation.cleanup = "none"` — see that file's header and "Rollback" above for why (a rollback can't undo what cleanup removes on the way in). Do not reintroduce imperative `brew cleanup` without revisiting that decision first. |
| `setup/install/12_krew.zsh` | `kubectl krew update`/`upgrade` + install `exec-as`, `exec-cronjob`, `node-shell`, `score`, `stern`, `open-svc` | `nix/modules/setup-tasks-common.nix`: `home.activation.krewPlugins` (best-effort, no-ops without `kubectl`) |
| `setup/install/13_helix.zsh` | `hx --grammar fetch` / `hx --grammar build` | `nix/modules/setup-tasks-common.nix`: `home.activation.helixGrammar` (best-effort, no-ops without `hx`) |
| `setup/install/14_slackcli.zsh` | download `slackcli` GitHub release into `~/.local/bin` by arch | `nix/modules/setup-tasks-common.nix`: `home.activation.slackcli` (best-effort, no-ops without `curl`) |
| `setup/install/15_agent_skills.zsh` | symlink `claude/skills/*` into `~/.claude/skills/<name>` | `nix/modules/setup-tasks-common.nix`: `home.file` (`claudeSkillFiles`) — fully declarative, not an activation hook |
| `setup/install/15_agent_skills.zsh` | `npx skills update` + `npx skills add <url> -g -y` for the external skills list | `nix/modules/setup-tasks-common.nix`: `home.activation.agentSkillsExternal` (best-effort, no-ops without `npx`) |
| `setup/install/29_macos.zsh` | `defaults write` macOS settings | `nix/modules/macos-defaults.nix` (mac-client only — unchanged by this pass, verified still complete against the original commands) |
| `setup/install/99_toy.zsh` | `brew install --cask wireshark` | `nix/hosts/mac-client/default.nix` `homebrew.casks` (unchanged by this pass, verified present) |

Note on `13_helix.zsh`: the `hx` binary itself is not declared anywhere in
this tree (it wasn't in the root Brewfile at the point of the Nix
migration either — this predates `setup-tasks-common.nix` and is out of
this table's scope). The grammar-fetch/build hook is guarded by
`command -v hx` so it's a safe no-op until/unless `hx` is installed on a
given host by some other means.

All four `home.activation` hooks in `setup-tasks-common.nix` are
intentionally imperative (Nix has no declarative primitive for "run a
network command after activation") but follow the same safety rules:
guarded by `command -v`, best-effort (a failure logs to stderr and moves
on, it does not fail the activation), and prefixed `$DRY_RUN_CMD` so
`--dry-run` doesn't execute them. See that file's header comment for the
full rationale.

## mise vs Nix

`mise` keeps owning **per-repository language runtime versions**. Nix
here owns **machine-wide CLI tooling** (`nix/modules/packages-common.nix`)
and the **Homebrew bridge** (everything else). Do not add a language
runtime (node, python, ruby, go, ...) to `home.packages` anywhere in this
tree — that recreates the exact "which one is authoritative" problem the
architect report flagged as a reason full migration isn't attractive.

## Expanding the Nix-native package list

`nix/modules/packages-common.nix` intentionally moved only ~20
unambiguous, well-known nixpkgs packages out of the former root Brewfile.
Before adding another package to that list:

1. Confirm the exact nixpkgs attribute name on a machine with Nix
   installed: `nix search nixpkgs <name>`. Brew formula names and nixpkgs
   attribute names frequently differ (e.g. Homebrew's `kubernetes-cli` is
   nixpkgs' `kubectl`; Homebrew's `awscli` is nixpkgs' `awscli2`) — this
   is exactly why those two stayed in the Homebrew bridge instead of being
   guessed at here.
2. Remove the corresponding entry from `nix/modules/homebrew-bridge-common.nix`
   (or the owning host's `homebrew.brews`/`homebrew.casks`) so the package
   isn't declared through two package managers at once (see "PATH
   collision" above).
3. Verify the binary actually resolves to the Nix-built one after
   activation (`which <binary>`), not a stale Homebrew shim.

## CI

`.github/workflows/ci.yml` runs three jobs:

- `legacy-artifacts-check` — greps the tree for anything the old
  Brewfile/`setup.zsh` flow would have left behind: a `Brewfile` anywhere,
  `setup/setup.zsh` or `setup/install.zsh`, a `brew bundle` invocation
  outside a `.zsh`/`.sh` script, a `vscode '...'` extension entry or `cask
  'cursor'` in a Brewfile, or `homebrew.vscode`/a `"cursor"` cask in Nix
  config. Fails the build if any of those reappear.
- `shellspec` — unchanged, runs the ShellSpec suite under `spec/` (tests
  for `bin/` scripts, unrelated to the install flow).
- `nix-flake-check` — installs Nix on a GitHub-hosted `macos-latest`
  runner (via `cachix/install-nix-action`) and runs `nix flake check`. It
  does not run `darwin-rebuild switch` or otherwise mutate anything
  outside the runner. Required to pass before a PR is mergeable; if it
  fails, fix the Nix option/package mismatch it surfaces rather than
  treating local heuristic checks (grep, brace-balance) as sufficient —
  those are a stand-in for real evaluation only where no local Nix
  install is available.

## VSCode/Cursor removal

VSCode/Cursor installation and extension management are discontinued in
this repo as of this migration:

- `cask 'cursor'` and the "Cursor Extensions" `vscode '...'` block (62
  entries) were removed from `setup/layers/mac-client/Brewfile` before
  that file itself was deleted along with the rest of the legacy
  Brewfile/setup flow (see "Status" above).
- The `vscode/` directory (`vscode/settings.json`, which only ever
  supported the VSCode/Cursor `User/settings.json` symlink) and its former
  deploy step in `setup/setup.zsh` are gone — both the directory and
  `setup/setup.zsh` itself no longer exist in this repo.
- Nothing in `nix/` declares `homebrew.vscode` (the nix-darwin option that
  would reintroduce extension management) — this is deliberate, not an
  oversight.
- If VSCode/Cursor support returns in the future, it needs a fresh design
  decision, not a revert of this removal — extension lists rot quickly and
  the ones removed here were not re-validated.
