{
  description = "neko-neko/dotfiles — nix-darwin multi-host config (mac-client, hermes-server, home-network)";

  # NOTE: this flake is the dotfiles install/management path. There is no
  # Brewfile or setup.zsh flow anymore — package installation, macOS
  # defaults, and dotfile deployment are all declared here and under
  # nix/. Evaluating/building this flake does not install or activate
  # anything by itself; see docs/nix-migration.md for the manual,
  # approval-gated apply flow (`darwin-rebuild switch`).

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # Pinned as flake inputs so `nix-homebrew` can manage the mandatory
    # homebrew/core and homebrew/cask taps declaratively. Third-party taps
    # (jesseduffield/*, hashicorp/tap, etc.) stay mutable — see
    # nix/modules/homebrew-bridge-common.nix and docs/nix-migration.md.
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, nix-homebrew, homebrew-core, homebrew-cask, ... }@inputs:
    let
      mkHost = { hostname, system ? "aarch64-darwin" }:
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./nix/modules/common.nix
            ./nix/modules/packages-common.nix
            ./nix/modules/homebrew-bridge-common.nix
            ./nix/modules/dotfiles-common.nix
            nix-homebrew.darwinModules.nix-homebrew
            home-manager.darwinModules.home-manager
            (./nix/hosts + "/${hostname}")
          ];
        };
    in
    {
      darwinConfigurations = {
        mac-client = mkHost { hostname = "mac-client"; };
        hermes-server = mkHost { hostname = "hermes-server"; };
        home-network = mkHost { hostname = "home-network"; };
      };
    };
}
