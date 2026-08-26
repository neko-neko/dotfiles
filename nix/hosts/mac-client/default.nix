# mac-client: personal Mac client (GUI + mobile dev + desktop apps).
# Package list is what used to be setup/layers/mac-client/Brewfile (removed
# — Nix is now the install path), MINUS the Cursor cask and the 60+
# `vscode` extension entries — VSCode/Cursor installation and extension
# management are discontinued in this repo (see README.md and
# docs/nix-migration.md "VSCode/Cursor removal").
{ config, lib, ... }:
{
  # REQUIRED: replace with this machine's actual macOS short username
  # (`whoami`) before running `darwin-rebuild build`/`switch` for real.
  # Left as a placeholder so `nix flake check` still evaluates cleanly for
  # everyone who clones this repo.
  system.primaryUser = "neko";

  users.users.neko = {
    name = "neko";
    home = "/Users/neko";
  };

  imports = [
    ../../modules/macos-defaults.nix
  ];

  homebrew.taps = [
    "dart-lang/dart"
    "leoafarias/fvm"
  ];

  homebrew.brews = [
    # Mobile Development
    "cocoapods"
    "fastlane"
    "firebase-cli"
    "leoafarias/fvm/fvm"

    # Mac App Store CLI (used by masApps below)
    "mas"
  ];

  homebrew.casks = [
    # Reverse engineering — interactive GUI app. Pairs with the headless
    # `ghidra, link: false` formula on hermes-server.
    "ghidra"

    "1password"
    "android-studio"
    "claude"
    "cyberduck"
    "dbeaver-community"
    "discord"
    "docker-desktop"
    "firefox"
    "flutter"
    "google-chrome"
    "jordanbaird-ice"
    "karabiner-elements"
    "keepingyouawake"
    "licecap"
    "netron"
    "ngrok"
    "notion"
    "notion-calendar"
    "notion-mail"
    "orbstack"
    "raycast"
    "slack"
    "ghostty"

    # Fonts
    "font-hack-nerd-font"
    "font-monaspace"

    # Misc (formerly setup/install/99_toy.zsh)
    "wireshark"
  ];

  # Requires being signed into the Mac App Store on this machine for `mas`
  # to succeed — see docs/nix-migration.md "Known risks".
  homebrew.masApps = {
    Keynote = 409183694;
    Kindle = 302584613;
  };
}
