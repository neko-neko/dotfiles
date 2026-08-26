# nix-darwin translation of setup/install/29_macos.zsh (`defaults write`
# commands). Imported by mac-client only, for now — see
# docs/nix-migration.md "macOS defaults" for why hermes-server (headless)
# and home-network (shared media box, different Dock/Finder expectations)
# don't get this module.
#
# Until this has been proven safe on a real machine (first `darwin-rebuild
# switch` on mac-client, per the runbook), 29_macos.zsh keeps running as
# part of the existing setup/install.zsh flow — the two are NOT wired
# together and can diverge. If you change one, update the other, or retire
# 29_macos.zsh once this module is confirmed equivalent.
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
