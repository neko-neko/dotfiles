# Mission Brief

- Target Role: IMPLEMENTATION_ORCHESTRATOR / local dotfiles maintenance worker
- Mission: Split the dotfiles Homebrew bundle into four purpose-specific Brewfiles and reduce server-side alias noise.
- Background:
  - This repo is used on the Tailscale Hermes server / development server and also on Mac client machines.
  - Current `Brewfile` mixes server, client GUI, and home-network/media packages; that installs unnecessary packages on the Hermes server.
  - Current `aliases` contains aliases based on a non-server client machine that add LLM-noisy output or replace classic CLI behavior; keep server usage clean.
  - There is already user-edited uncommitted work in `aliases`; preserve the intent and fix obvious accidental corruption if found.
- Inputs / Paths:
  - Repo: `/Users/nishikataseiichi/.dotfiles`
  - Existing main Brewfile: `/Users/nishikataseiichi/.dotfiles/Brewfile`
  - Existing home-network layer: `/Users/nishikataseiichi/.dotfiles/setup/layers/home-network/Brewfile`
  - Installer: `/Users/nishikataseiichi/.dotfiles/setup/install.zsh`
  - Aliases: `/Users/nishikataseiichi/.dotfiles/aliases`
- Required classification:
  - Create/keep a common Brewfile for packages suitable for both Hermes server and Mac client.
  - Create a Hermes Server Brewfile for server/development-server-only packages.
  - Create a Mac Client Brewfile for GUI/client/mobile/desktop-only packages.
  - Create a separate Home Network Brewfile for Jellyfin/media/home-network packages. Existing `setup/layers/home-network/Brewfile` should become/hold that layer. Include Jellyfin there if Homebrew supports it; do not leave it in server/client/common.
- Constraints:
  - Do NOT push, merge, deploy, or run `brew bundle`/install commands.
  - Local file edits only.
  - Prefer simple documented file names that are obvious for agents and humans. Keep `Brewfile` as the common/default bundle if that is the least surprising path.
  - Update installer/docs enough that future agents know how to install common+target layers without installing all packages on server.
  - Keep Ruby Brewfile syntax valid.
  - Preserve existing comments/categories where practical.
  - Do not delete unrelated files or touch Claude skills unless necessary.
- Expected Outputs:
  - Updated/split Brewfile files.
  - Updated install script and/or README documenting target selection.
  - Aliases adjusted so server default avoids noisy aliases; client-only aliases should be guarded or moved to `.aliases.local` guidance if appropriate.
  - A concise local report at `.hermes/dotfiles-brewfile-split-report.md` with files changed and verification commands/results.
- Definition of Done:
  - `git diff --stat` shows only relevant dotfiles changes.
  - `ruby -c` passes for all Brewfile files (Homebrew Brewfiles are Ruby DSL).
  - `zsh -n aliases setup/install.zsh setup/setup.zsh` passes.
  - No command installs packages or writes external systems.

Please implement now. End with:
STATE:
FILES_CHANGED:
COMMANDS_RUN:
RESULT:
BLOCKER:
NEXT_ACTION:
