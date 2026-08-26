# hermes-server: headless Tailscale dev/server box. Package list is what
# used to be setup/layers/hermes-server/Brewfile (removed — Nix is now the
# install path). No GUI casks, no macOS defaults module (headless — see
# nix/modules/macos-defaults.nix header).
{ ... }:
{
  # REQUIRED: replace with this machine's actual macOS short username
  # (`whoami`) before running `darwin-rebuild build`/`switch` for real.
  system.primaryUser = "neko";

  users.users.neko = {
    name = "neko";
    home = "/Users/neko";
  };

  homebrew.brews = [
    # Tailscale connectivity for the Hermes server itself. Stays
    # Homebrew-managed — nix-darwin has no NixOS-style `services.tailscale`
    # module (see /tmp/dotfiles-nix-architect-report.md §3).
    "tailscale"

    # Reverse engineering — headless/batch analysis (analyzeHeadless).
    # Pairs with the interactive `ghidra` cask on mac-client.
    { name = "ghidra"; link = false; }
  ];
}
