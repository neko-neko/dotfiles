# Home Manager coverage for the former setup/install/{12_krew,13_helix,
# 14_slackcli,15_agent_skills}.zsh (all removed in ddfebf0 — see
# docs/nix-migration.md "Former setup script coverage" for the full
# script-to-replacement map). These four were NOT package installs (those
# are covered by nix/modules/packages-common.nix and
# nix/modules/homebrew-bridge-common.nix) — they were post-install
# activation steps: kubectl-krew plugin fetch, Helix grammar build,
# a GitHub-release binary download, and repo-local + external Claude
# skill sync. Nix has no declarative primitive for "run this network
# command after activation", so those four stay imperative here, via
# Home Manager `home.activation` hooks, per the following rules (see
# docs/nix-migration.md for the rationale):
#
#   - every external command is guarded by `command -v` so a host missing
#     the relevant tool (e.g. hermes-server has no interactive `hx`) is a
#     silent no-op, not a failure;
#   - every command is best-effort (`|| true` / a caught non-zero exit) so
#     one failing network call (GitHub down, npx registry unreachable)
#     cannot fail the whole `darwin-rebuild switch`/`home-manager switch`;
#   - mutating commands are prefixed `$DRY_RUN_CMD` per the Home Manager
#     activation-script convention, so `--dry-run` doesn't execute them.
#
# The repo-local Claude skills symlinks ARE fully declarative (home.file,
# not activation) — see claudeSkillFiles below.
{ config, lib, ... }:
let
  repoRoot = ../..;
  claudeSkillsDir = repoRoot + "/claude/skills";

  # Mirrors the former setup/install/15_agent_skills.zsh symlink loop
  # (`ln -sfv ~/.dotfiles/claude/skills/<name> ~/.claude/skills/<name>`),
  # but declaratively: every claude/skills/<name>/ directory that has a
  # SKILL.md is linked whole-directory under ~/.claude/skills/<name>.
  # Whole-directory linking is safe here on the same grounds as
  # dotfiles-common.nix's `.functions`/`.bin` entries — skill directories
  # are source-only (SKILL.md + reference files), nothing writes into them
  # at runtime.
  claudeSkillNames = builtins.attrNames (
    lib.filterAttrs
      (name: type: type == "directory" && builtins.pathExists (claudeSkillsDir + "/${name}/SKILL.md"))
      (builtins.readDir claudeSkillsDir)
  );
  claudeSkillFiles = lib.listToAttrs (
    map
      (name: {
        name = ".claude/skills/${name}";
        value.source = claudeSkillsDir + "/${name}";
      })
      claudeSkillNames
  );

  # Former setup/install/15_agent_skills.zsh external_skills list, run via
  # `npx skills add <args> -g -y`. Kept as one string per entry (URL plus
  # optional trailing `--skill ...` flags) so unquoted bash word-splitting
  # in the activation script reproduces the original zsh `${=skill}`
  # splitting.
  externalSkillArgs = [
    "https://github.com/googleworkspace/cli/tree/main/skills/gws-calendar"
    "https://github.com/googleworkspace/cli/tree/main/skills/gws-docs"
    "https://github.com/googleworkspace/cli/tree/main/skills/gws-drive"
    "https://github.com/googleworkspace/cli/tree/main/skills/gws-gmail"
    "https://github.com/googleworkspace/cli/tree/main/skills/gws-sheets"
    "https://github.com/anthropics/skills --skill skill-creator"
    "vercel-labs/agent-browser --skill agent-browser --skill dogfood"
    "vercel-labs/agent-skills --skill react-best-practices --skill composition-patterns --skill web-design-guidelines"
    "https://github.com/github/awesome-copilot --skill breakdown-test"
    "mattpocock/skills"
    "ogulcancelik/herdr"
  ];

  # Former setup/install/12_krew.zsh plugin list.
  krewPlugins = [
    "exec-as"
    "exec-cronjob"
    "node-shell"
    "score"
    "stern"
    "open-svc"
  ];
in
{
  home-manager.users.${config.system.primaryUser} = { lib, ... }: {
    home.file = claudeSkillFiles;

    # Former setup/install/12_krew.zsh: `kubectl krew update`, `upgrade`,
    # then install each plugin. Requires the `krew` formula (already
    # declared in nix/modules/homebrew-bridge-common.nix) to provide the
    # `kubectl-krew` binary on PATH; no-ops entirely if `kubectl` isn't
    # present (e.g. a host with no Kubernetes tooling).
    home.activation.krewPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if command -v kubectl >/dev/null 2>&1; then
        $DRY_RUN_CMD kubectl krew update || true
        $DRY_RUN_CMD kubectl krew upgrade || true
        ${lib.concatMapStringsSep "\n        " (p: ''$DRY_RUN_CMD kubectl krew install ${p} || true'') krewPlugins}
      fi
    '';

    # Former setup/install/13_helix.zsh: fetch + build tree-sitter
    # grammars for the Helix config this repo deploys (see
    # nix/modules/dotfiles-common.nix's helix/*.toml entries). No-ops if
    # `hx` isn't installed on this host (helix itself is not declared
    # anywhere in this tree yet — see docs/nix-migration.md "Former setup
    # script coverage").
    home.activation.helixGrammar = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if command -v hx >/dev/null 2>&1; then
        $DRY_RUN_CMD hx --grammar fetch || true
        $DRY_RUN_CMD hx --grammar build || true
      fi
    '';

    # Former setup/install/14_slackcli.zsh: download the slackcli binary
    # release matching this host's architecture into ~/.local/bin, only
    # when a newer version is available than what's already installed.
    home.activation.slackcli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if command -v curl >/dev/null 2>&1; then
        install_dir="$HOME/.local/bin"
        $DRY_RUN_CMD mkdir -p "$install_dir"

        arch="$(uname -m)"
        binary_name="slackcli-macos-arm64"
        if [[ "$arch" = "x86_64" ]]; then
          binary_name="slackcli-macos"
        fi

        latest_version="$(curl -fsS https://api.github.com/repos/shaharia-lab/slackcli/releases/latest 2>/dev/null | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')"
        if [[ -n "$latest_version" ]]; then
          current_version=""
          if [[ -x "$install_dir/slackcli" ]]; then
            current_version="$("$install_dir/slackcli" --version 2>/dev/null)"
          fi
          if [[ "$current_version" != "$latest_version" ]]; then
            url="https://github.com/shaharia-lab/slackcli/releases/download/v$latest_version/$binary_name"
            if $DRY_RUN_CMD curl -fSL -o "$install_dir/slackcli" "$url"; then
              $DRY_RUN_CMD chmod +x "$install_dir/slackcli"
            else
              echo "setup-tasks: failed to download slackcli, skipping" >&2
            fi
          fi
        else
          echo "setup-tasks: failed to fetch latest slackcli version, skipping" >&2
        fi
      fi
    '';

    # Former setup/install/15_agent_skills.zsh's external-skills half
    # (the repo-local half is the declarative home.file.claudeSkillFiles
    # above). `--yes` is added to `npx` itself — not present in the
    # original script — because an activation hook has no TTY to answer
    # npx's "install this package? (y)" prompt; without it, a cold npx
    # cache would hang activation instead of failing safely.
    home.activation.agentSkillsExternal = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if command -v npx >/dev/null 2>&1; then
        $DRY_RUN_CMD npx --yes skills update || echo "setup-tasks: npx skills update failed, continuing" >&2
        for skill_args in \
          ${lib.concatMapStringsSep " \\\n          " (s: "\"${s}\"") externalSkillArgs}
        do
          $DRY_RUN_CMD npx --yes skills add $skill_args -g -y || echo "setup-tasks: npx skills add ($skill_args) failed, continuing" >&2
        done
      fi
    '';
  };
}
