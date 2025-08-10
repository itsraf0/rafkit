#!/usr/bin/env bash
set -euo pipefail

# ─── Helper Functions ──────────────────────────────────────────────────────────

info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; exit 1; }

is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }
is_arch_like() {
  if [[ -f /etc/os-release ]]; then
    grep -Eq '(^ID=arch|ID_LIKE=.*arch.*)' /etc/os-release && return 0
  fi
  command -v pacman >/dev/null 2>&1
}

# ─── 0. Self-update ~/rafkit and restart if updated ────────────────────────────

self_update_rafkit() {
  local RAFKIT_DIR="${HOME}/rafkit"
  if [[ ! -d "$RAFKIT_DIR/.git" ]]; then
    warn "~/rafkit not found or not a git repo; skipping self-update check."
    return 0
  fi

  info "Checking ~/rafkit for updates..."
  pushd "$RAFKIT_DIR" >/dev/null || return 0

  # Ensure we're on main (match your snippet)
  if ! git checkout main >/dev/null 2>&1; then
    warn "Could not checkout 'main' in ~/rafkit; continuing."
  fi

  if ! git fetch origin main >/dev/null 2>&1; then
    warn "git fetch failed; skipping rafkit update check."
    popd >/dev/null || true
    return 0
  fi

  local LOCAL REMOTE
  LOCAL=$(git rev-parse HEAD || echo "")
  REMOTE=$(git rev-parse origin/main || echo "")

  if [[ -n "$LOCAL" && -n "$REMOTE" && "$LOCAL" != "$REMOTE" ]]; then
    info "Pulling latest changes for ~/rafkit..."
    if git pull --ff-only; then
      popd >/dev/null || true
      info "Repo updated. Re-executing this script..."
      exec "$0" "${@-}"
    else
      warn "git pull failed; continuing without restart."
      popd >/dev/null || true
    fi
  else
    info "rafkit is up-to-date."
    popd >/dev/null || true
  fi
}

self_update_rafkit "$@"

# ─── 1. Homebrew (macOS or Linuxbrew) ─────────────────────────────────────────

if command -v brew >/dev/null 2>&1; then
  info "Updating Homebrew..."
  brew update

  info "Upgrading installed formulae..."
  brew upgrade

  if is_macos; then
    info "Upgrading Homebrew casks..."
    # casks are macOS-only
    brew upgrade --cask || warn "brew cask upgrade failed"
  fi

  info "Cleaning up Homebrew cache and old versions..."
  brew cleanup || warn "brew cleanup failed"
else
  warn "Homebrew not found; skipping brew updates."
fi

# ─── 2. Arch Linux package managers (pacman & yay) ────────────────────────────

if is_arch_like; then
  if command -v pacman >/dev/null 2>&1; then
    info "Updating system packages with pacman (may prompt for sudo)..."
    sudo pacman -Syu || warn "pacman -Syu failed"
  else
    warn "pacman not found; skipping pacman."
  fi

  if command -v yay >/dev/null 2>&1; then
    info "Updating AUR packages with yay..."
    # -Sua updates only AUR; avoids re-running full repo upgrades
    yay -Sua --devel || warn "yay AUR update failed"
  else
    warn "yay not found; skipping AUR updates."
  fi
fi

# ─── 3. Other package managers ────────────────────────────────────────────────

# npm (global)
if command -v npm >/dev/null 2>&1; then
  info "Updating npm globals..."
  npm update -g || warn "npm global update failed"
else
  warn "npm not found; skipping npm update."
fi

# pnpm
if command -v pnpm >/dev/null 2>&1; then
  info "Updating pnpm globals..."
  pnpm update -g || warn "pnpm global update failed"
else
  warn "pnpm not found; skipping pnpm update."
fi

# yarn
if command -v yarn >/dev/null 2>&1; then
  info "Updating yarn globals..."
  yarn global upgrade || warn "yarn global upgrade failed"
else
  warn "yarn not found; skipping yarn update."
fi

# pipx
if command -v pipx >/dev/null 2>&1; then
  info "Upgrading all pipx packages..."
  pipx upgrade-all || warn "pipx upgrade-all failed"
else
  warn "pipx not found; skipping pipx upgrade."
fi

# ─── 4. Clean up caches (only when tool exists) ───────────────────────────────

if command -v pnpm >/dev/null 2>&1; then
  info "Cleaning pnpm store..."
  pnpm store prune || warn "pnpm store prune failed"
fi

if command -v yarn >/dev/null 2>&1; then
  info "Cleaning yarn cache..."
  yarn cache clean || warn "yarn cache clean failed"
fi

if is_macos; then
  info "Emptying macOS Trash..."
  rm -rf ~/.Trash/* || warn "Failed to empty macOS Trash"
fi

# ─── 5. Run your custom fetch script ──────────────────────────────────────────

FETCH_SCRIPT=~/dev/rafkit/sysfetch.sh
if [[ -x "$FETCH_SCRIPT" ]]; then
  info "Running sysfetch.sh..."
  "$FETCH_SCRIPT"
else
  warn "sysfetch.sh not found or not executable at $FETCH_SCRIPT"
fi

# ─── 6. Prompt to sort files ──────────────────────────────────────────────────

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

info "All done! 🎉"
