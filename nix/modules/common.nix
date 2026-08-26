# Shared nix-darwin configuration for every host (mac-client, hermes-server,
# home-network). Host files under nix/hosts/<host>/default.nix import this
# plus the role-specific modules and layer on their own homebrew.* entries.
#
# Scope boundary (see docs/nix-migration.md "mise vs Nix"): this manages
# machine-wide CLI tooling and macOS/Homebrew bridging only. `mise` keeps
# owning per-repository language runtime versions — do not add language
# runtimes (node, python, ruby, go, ...) to home.packages anywhere in this
# tree; that would create two sources of truth for the same runtime.
{ config, pkgs, lib, inputs, ... }:
{
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Nix manages its own daemon/store on a Determinate Nix install; leave
  # nix.enable at its nix-darwin default rather than fighting the
  # installer's configuration.

  # nix-darwin release compatibility marker. Confirm against the actual
  # installed nix-darwin version on first real `darwin-rebuild` run
  # (`darwin-version`) before changing — see docs/nix-migration.md.
  system.stateVersion = 6;

  # home.stateVersion (the equivalent per-user compatibility marker) is set
  # in nix/modules/packages-common.nix, alongside home.packages.
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "hm-bak";

  # nix-homebrew: manage the mandatory homebrew/core + homebrew/cask taps
  # declaratively via the pinned flake inputs. mutableTaps stays true
  # because the existing Brewfiles depend on many third-party taps
  # (jesseduffield/*, hashicorp/tap, etc.) that are not flake-pinned here —
  # forcing mutableTaps = false would require pinning every one of them as
  # a flake input first. autoMigrate lets this attach to an existing,
  # already-populated Homebrew install without wiping it.
  nix-homebrew = {
    enable = true;
    user = config.system.primaryUser;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
    };
    mutableTaps = true;
    autoMigrate = true;
  };
}
