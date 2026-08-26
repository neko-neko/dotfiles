# nix-darwin translation of the former setup/install/29_macos.zsh
# (`defaults write` commands; the script is removed — this module is now
# the only source of these settings). Imported by mac-client only — see
# docs/nix-migration.md "macOS defaults" for why hermes-server (headless)
# and home-network (shared media box, different Dock/Finder expectations)
# don't get this module.
#
# Not yet exercised by a real `darwin-rebuild switch` (no local Nix
# install available when this was written/migrated — see
# docs/nix-migration.md "Known risks"). Verify against the original
# `defaults write` commands (git history) if these values are ever in
# doubt.
{ ... }:
{
  system.defaults.NSGlobalDomain.InitialKeyRepeat = 10;
  system.defaults.NSGlobalDomain.KeyRepeat = 1;
  system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;

  system.defaults.finder.AppleShowAllFiles = true;

  system.defaults.dock.orientation = "left";
  system.defaults.dock.autohide = true;
  # Matches `defaults write com.apple.dock persistent-apps -array` (clears
  # pinned Dock icons).
  system.defaults.dock.persistent-apps = [ ];
}
