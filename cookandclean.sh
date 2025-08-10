#!/usr/bin/env bash
set -euo pipefail

# ─── Helper Functions ──────────────────────────────────────────────────────────

info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; exit 1; }

# ─── OS Detection ──────────────────────────────────────────────────────────────

OS="$(uname -s)"
IS_MAC=false
IS_LINUX=false
IS_ARCH=false

if [[ "$OS" == "Darwin" ]]; then
  IS_MAC=true
elif [[ "$OS" == "Linux" ]]; then
  IS_LINUX=true
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    if [[ "${ID:-}" == "arch" || "${ID_LIKE:-}" == *"arch"* || "${NAME:-}" == *"Arch"* ]]; then
      IS_ARCH=true
    fi
  fi
fi

if $IS_MAC; then
  info "Detected macOS."
elif $IS_ARCH; then
  info "Detected Arch Linux."
elif $IS_LINUX; then
  info "Detected Linux (non-Arch). Arch-specific steps will be skipped."
else
  warn "Unknown OS: $OS"
fi

# ─── 1. Update Homebrew (macOS and Linuxbrew) ──────────────────────────────────

if command -v brew &>/dev/null; then
  info "Updating Homebrew..."
  brew update

  info "Upgrading Homebrew formulae..."
  brew upgrade

  if $IS_MAC; then
    info "Upgrading Homebrew casks (macOS only)..."
    brew upgrade --cask || warn "brew cask upgrade failed"
  fi

  info "Cleaning up Homebrew cache and old versions..."
  brew cleanup || warn "brew cleanup failed"
else
  warn "Homebrew not found; skipping brew steps."
fi

# ─── 2. Update Arch packages (yay / pacman) ────────────────────────────────────

if $IS_ARCH; then
  if [[ -f /var/lib/pacman/db.lck ]]; then
    warn "pacman database lock present (/var/lib/pacman/db.lck). Another package manager may be running. Skipping pacman/yay updates."
  else
    if command -v yay &>/dev/null; then
      info "Updating packages with yay (covers repo + AUR)..."
      yay -Syu --noconfirm || error "yay -Syu failed"

      info "Cleaning yay cache..."
      yay -Sc --noconfirm || warn "yay cache clean failed"
    elif command -v pacman &>/dev/null; then
      info "Updating packages with pacman..."
      sudo pacman -Syu --noconfirm || error "pacman -Syu failed"

      # Optional: remove orphaned packages (quiet if none)
      info "Removing orphaned packages (if any)..."
      orphans="$(pacman -Qtdq 2>/dev/null || true)"
      if [[ -n "${orphans:-}" ]]; then
        sudo pacman -Rns --noconfirm $orphans || warn "Failed to remove some orphans"
      else
        info "No orphaned packages found."
      fi

      info "Cleaning pacman cache (keep last 3 versions if paccache is available)..."
      if command -v paccache &>/dev/null; then
        sudo paccache -rk3 || warn "paccache clean failed"
      else
        sudo pacman -Sc --noconfirm || warn "pacman cache clean failed"
      fi
    else
      warn "Neither yay nor pacman found; skipping Arch package updates."
    fi
  fi
fi

# ─── 3. Update other package managers ──────────────────────────────────────────

# npm (global)
if command -v npm &>/dev/null; then
  info "Updating npm globals..."
  npm update -g || warn "npm global update failed"
else
  warn "npm not found; skipping npm update"
fi

# pnpm
if command -v pnpm &>/dev/null; then
  info "Updating pnpm globals..."
  pnpm update -g || warn "pnpm global update failed"
else
  warn "pnpm not found; skipping pnpm update"
fi

# yarn (classic global)
if command -v yarn &>/dev/null; then
  info "Updating yarn global packages..."
  yarn global upgrade || warn "yarn global upgrade failed"
else
  warn "yarn not found; skipping yarn update"
fi

# pipx
if command -v pipx &>/dev/null; then
  info "Upgrading all pipx packages..."
  pipx upgrade-all || warn "pipx upgrade-all failed"
else
  warn "pipx not found; skipping pipx upgrade"
fi

# ─── 4. Clean up caches ────────────────────────────────────────────────────────

# pnpm
if command -v pnpm &>/dev/null; then
  info "Cleaning pnpm store..."
  pnpm store prune || warn "pnpm store prune failed"
fi

# yarn
if command -v yarn &>/dev/null; then
  info "Cleaning yarn cache..."
  yarn cache clean || warn "yarn cache clean failed"
fi

# macOS Trash (mac only; safe guard if folder absent/empty)
if $IS_MAC; then
  if [[ -d "$HOME/.Trash" ]]; then
    info "Emptying macOS Trash..."
    rm -rf "$HOME/.Trash/"* 2>/dev/null || true
  fi
fi

# ─── 5. Run your custom fetch script ───────────────────────────────────────────

FETCH_SCRIPT=~/dev/rafkit/sysfetch.sh
if [[ -x "$FETCH_SCRIPT" ]]; then
  info "Running sysfetch.sh..."
  "$FETCH_SCRIPT"
else
  warn "sysfetch.sh not found or not executable at $FETCH_SCRIPT"
fi

# ─── 6. Prompt to sort files ───────────────────────────────────────────────────

SORT_SCRIPT=~/dev/rafkit/sort-files.sh
echo
read -rp "Would you like to run sort-files.sh? [y/n] " REPLY
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  if [[ -x "$SORT_SCRIPT" ]]; then
    info "Running sort-files.sh -v..."
    "$SORT_SCRIPT" -v
  else
    error "sort-files.sh not found or not executable at $SORT_SCRIPT"
  fi
else
  info "Skipping sort-files.sh."
fi
cd rafkit
git checkout main
git pull

info "All done! 🎉"