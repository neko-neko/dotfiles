# Home Manager mapping of this repo's dotfiles onto $HOME, for every host.
# This replaces the former setup/setup.zsh symlink loop (removed — Nix is
# now the install/management path for dotfiles, not just packages).
#
# Root-level files/dirs deploy straight under $HOME as dotfiles.
# config/<name> deploys under XDG_CONFIG_HOME (~/.config).
#
# config/* entries are mapped FILE BY FILE, not as whole directories,
# because some tools write runtime files alongside their own config (e.g.
# herdr writes into config/herdr/... — see docs/nix-migration.md). A
# directory-level xdg.configFile would make that whole tree a read-only
# Nix-store symlink and break that. If a tool adds a new file under one of
# these config/<name> dirs, add the matching line below — it will not
# appear under $HOME automatically just by existing in the repo.
#
# claude/ is intentionally NOT mapped here — it stays repo-local source
# only, per the migration scope (see docs/nix-migration.md).
{ config, ... }:
let
  repoRoot = ../..;
in
{
  home-manager.users.${config.system.primaryUser} = { ... }: {
    home.file = {
      ".aliases".source = repoRoot + "/aliases";
      ".zshrc".source = repoRoot + "/zshrc";
      ".zshenv".source = repoRoot + "/zshenv";
      ".gitconfig".source = repoRoot + "/gitconfig";
      ".gitignore_global".source = repoRoot + "/gitignore_global";
      ".gemrc".source = repoRoot + "/gemrc";
      ".editorconfig".source = repoRoot + "/editorconfig";
      ".hushlogin".source = repoRoot + "/hushlogin";
      # Whole-directory link is safe here — neither dir receives runtime
      # writes (functions/ is zsh autoload sources, bin/ is scripts only).
      ".functions".source = repoRoot + "/functions";
      ".bin".source = repoRoot + "/bin";
    };

    xdg.configFile = {
      "ccstatusline/settings.json".source = repoRoot + "/config/ccstatusline/settings.json";

      "ghostty/config".source = repoRoot + "/config/ghostty/config";

      "helix/config.toml".source = repoRoot + "/config/helix/config.toml";
      "helix/languages.toml".source = repoRoot + "/config/helix/languages.toml";

      "herdr/config.toml".source = repoRoot + "/config/herdr/config.toml";
      "herdr/plugins.json".source = repoRoot + "/config/herdr/plugins.json";
      "herdr/plugins/drop-upload/herdr-plugin.toml".source = repoRoot + "/config/herdr/plugins/drop-upload/herdr-plugin.toml";
      "herdr/plugins/drop-upload/scripts/action-start.sh".source = repoRoot + "/config/herdr/plugins/drop-upload/scripts/action-start.sh";
      "herdr/plugins/drop-upload/scripts/overlay.sh".source = repoRoot + "/config/herdr/plugins/drop-upload/scripts/overlay.sh";
      "herdr/plugins/drop-upload/lib/core.sh".source = repoRoot + "/config/herdr/plugins/drop-upload/lib/core.sh";

      "karabiner/karabiner.json".source = repoRoot + "/config/karabiner/karabiner.json";
      "karabiner/assets/complex_modifications/1513924179.json".source = repoRoot + "/config/karabiner/assets/complex_modifications/1513924179.json";
      "karabiner/assets/complex_modifications/1513924035.json".source = repoRoot + "/config/karabiner/assets/complex_modifications/1513924035.json";
      "karabiner/assets/complex_modifications/1513924106.json".source = repoRoot + "/config/karabiner/assets/complex_modifications/1513924106.json";

      "mise/config.toml".source = repoRoot + "/config/mise/config.toml";

      "sesh/sesh.toml".source = repoRoot + "/config/sesh/sesh.toml";

      "sheldon/plugins.toml".source = repoRoot + "/config/sheldon/plugins.toml";

      "starship.toml".source = repoRoot + "/config/starship.toml";
    };
  };
}
