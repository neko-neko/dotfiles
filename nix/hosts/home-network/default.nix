# home-network: Mac mini running shared/family media + network services.
# Package list is what used to be setup/layers/home-network/Brewfile
# (removed — Nix is now the install path). This is Phase 5 — the
# highest-risk host (family-used production services) — so everything
# here stays on the Homebrew bridge rather than an unproven Nix-native
# launchd rewrite. See docs/nix-migration.md "Phase 5: home-network" for
# the full rationale and the rehearsal-before-touching-this-host plan.
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
    # adguardhome/syncthing: nix-darwin has no first-class services module
    # for either (unlike NixOS's services.adguardhome/services.syncthing —
    # confirmed absent in nix-darwin's module set, see
    # /tmp/dotfiles-nix-reviewer-report.md). Hand-writing launchd.daemons
    # units for a family-used production media box, without a rehearsal
    # environment, is exactly the risk the architecture report flags for
    # last-phase-only work. Documented safe fallback: keep both
    # Homebrew-managed, but declared here so the intent to eventually move
    # them to launchd.daemons (once rehearsed on a disposable host) is
    # tracked in one place instead of silently living only in a Brewfile.
    "adguardhome"
    "syncthing"
  ];

  homebrew.casks = [
    # Jellyfin stays Homebrew-cask permanently by design (owner directive):
    # the cask tracks upstream's full installer/updater/plugin ecosystem,
    # which a bare Nix package would not replicate.
    "jellyfin"
  ];
}
