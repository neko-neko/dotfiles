# Common Nix-native CLI packages, shared by every host.
#
# This is a deliberately CONSERVATIVE starter set: only tools whose nixpkgs
# attribute name is well-known and unambiguous were moved here from the
# root Brewfile. Everything else stays declared in
# nix/modules/homebrew-bridge-common.nix (still Homebrew-installed, still
# under nix-darwin's declarative management) rather than guessed at.
#
# Do NOT add a package here without first confirming its exact nixpkgs
# attribute name on a machine with Nix installed (`nix search nixpkgs
# <name>`) — a wrong attribute name breaks `nix flake check` for every
# host. See docs/nix-migration.md "Expanding the Nix-native package list".
{ config, pkgs, ... }:
let
  commonPackages = with pkgs; [
    # Shell & Terminal
    fzf
    zoxide
    starship
    direnv
    ast-grep

    # Git & Version Control
    git
    git-lfs
    gh
    lazygit

    # Alternatives to classic CLI (mirrors root Brewfile's "Alternatives to
    # classic CLI" section naming, kept 1:1 where the nixpkgs attribute
    # matches)
    bat
    bottom
    jq
    ripgrep
    tldr

    # GNU & Utilities / networking
    tree
    curl
    wget
    gnupg
    imagemagick
    nmap
    mosh
  ];
in
{
  home-manager.users.${config.system.primaryUser} = { ... }: {
    home.packages = commonPackages;

    # home-manager release compatibility marker — keep at the value first
    # used for this config; only bump after reading the Home Manager
    # release notes (see nix/modules/common.nix for the same convention on
    # the nix-darwin side).
    home.stateVersion = "24.11";
  };
}
