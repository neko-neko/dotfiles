# nix-darwin Homebrew bridge for what the former root Brewfile (removed —
# Nix is now the install path) needed Homebrew to install: third-party
# taps, packages without a confidently correct nixpkgs attribute name, and
# CLI-only casks (gcloud, codex, 1Password CLI). nix-darwin's `homebrew.*`
# module generates a Brewfile and runs `brew bundle` on activation — see
# Context7 findings in /tmp/dotfiles-nix-architect-report.md §6 — so
# installation still happens through Homebrew for these, but the
# declaration now lives only here, not in a hand-maintained Brewfile.
#
# This is the mirror image of nix/modules/packages-common.nix: every
# package below was deliberately NOT moved there (uncertain nixpkgs name,
# third-party tap dependency, or Homebrew-cask-only). It does not
# duplicate anything in packages-common.nix.
#
# onActivation.cleanup stays "none" (the nix-darwin default): switching it
# to "uninstall"/"zap" would let a future `darwin-rebuild switch` delete
# any locally-installed Homebrew package not listed here. Do not change
# this without reading docs/nix-migration.md "Rollback" first.
{ config, lib, ... }:
{
  homebrew.enable = true;
  homebrew.onActivation.cleanup = "none";

  homebrew.taps = (builtins.attrNames config.nix-homebrew.taps) ++ [
    "boz/repo"
    "derailed/k9s"
    "getsentry/tools"
    "golangci/tap"
    "hashicorp/tap"
    "jesseduffield/lazydocker"
    "jesseduffield/lazygit"
    "johanhaleby/kubetail"
    "ktr0731/evans"
    "oven-sh/bun"
    "schpet/tap"
    "rjyo/moshi"
  ];

  homebrew.brews = [
    # Taps for tools
    "boz/repo/kail"
    "derailed/k9s/k9s"
    "getsentry/tools/sentry-wizard"
    "golangci/tap/golangci-lint"
    "hashicorp/tap/terraform-ls"
    "jesseduffield/lazydocker/lazydocker"
    "johanhaleby/kubetail/kubetail"
    "ktr0731/evans/evans"
    "oven-sh/bun/bun"
    "schpet/tap/linear"
    "gum"

    # GNU & Utilities (build toolchain / library packages not moved to
    # home.packages — see packages-common.nix header for why)
    "autoconf"
    "binutils"
    "cairo"
    "cmake"
    "coreutils"
    "diffutils"
    "findutils"
    "gawk"
    "gcc"
    "gettext"
    "giflib"
    "gmp"
    "gnu-indent"
    "gnu-sed"
    "gnu-tar"
    "gnu-which"
    "gnutls"
    "grep"
    "jpeg"
    "lhasa"
    "libpng"
    "libpq"
    "librsvg"
    "libyaml"
    "make"
    "nkf"
    "openssl@3"
    "pango"
    "pixman"
    "pkgconf"
    "source-highlight"
    "vips"

    # Shell & Terminal (custom/niche taps, not in nixpkgs)
    "sheldon"
    "herdr"
    "hunk"
    "moshi-hook"

    # Editors
    "neovim"

    # Git & Version Control
    "diff-so-fancy"
    "ghq"
    "gibo"
    "git-delta"
    "worktrunk"

    # Cloud & DevOps
    "argocd"
    "awscli"
    "azure-cli"
    "cloudflared"
    { name = "docker"; link = false; }
    "hadolint"
    "helm"
    "heroku"
    "istioctl"
    "krew"
    "kubernetes-cli"
    "kubectx"
    "kubeseal"
    "sops"
    "tflint"

    # Languages & Runtimes
    "lua"
    "mise"
    "mysql-client"
    "protobuf"
    "uv"

    # AI Tools
    "gemini-cli"

    # LSPs
    "bash-language-server"
    "dockerfile-language-server"
    "yaml-language-server"

    # Alternatives to classic CLI (not moved — see packages-common.nix)
    "fx"
    "q"

    # Other
    "grip"
  ];

  homebrew.casks = [
    "gcloud-cli"
    "codex" # OpenAI Codex CLI agent (terminal tool, not a GUI app)
    "1password-cli"
  ];
}
