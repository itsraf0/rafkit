#!/usr/bin/env bash
set -euo pipefail

# ─── Helper Functions ──────────────────────────────────────────────────────────

info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; exit 1; }

# ─── 1. Update Homebrew and formulae ────────────────────────────────────────────

info "Updating Homebrew..."
brew update

info "Upgrading installed formulae and casks..."
brew upgrade
brew upgrade --cask

# ─── 2. Update other package managers ───────────────────────────────────────────

# npm (global)
if command -v npm &>/dev/null; then
  info "Updating npm globals..."
  npm update -g
else
  warn "npm not found; skipping npm update"
fi

# pnpm
if command -v pnpm &>/dev/null; then
  info "Updating pnpm globals..."
  pnpm update -g
else
  warn "pnpm not found; skipping pnpm update"
fi

# yarn
if command -v yarn &>/dev/null; then
  info "Updating yarn globals..."
  yarn global upgrade
else
  warn "yarn not found; skipping yarn update"
fi

# pipx
if command -v pipx &>/dev/null; then
  info "Upgrading all pipx packages..."
  pipx upgrade-all
else
  warn "pipx not found; skipping pipx upgrade"
fi

# ─── 3. Clean up caches and old files ───────────────────────────────────────────

info "Cleaning up Homebrew cache and old versions..."
brew cleanup

info "Cleaning pnpm store..."
pnpm store prune || warn "pnpm store prune failed"

info "Cleaning yarn cache..."
yarn cache clean || warn "yarn cache clean failed"

# Optionally empty the Trash:
info "Emptying macOS Trash..."
rm -rf ~/.Trash/*

# ─── 4. Run your custom fetch script ───────────────────────────────────────────

FETCH_SCRIPT=~/dev/rafkit/macfetch.sh
if [[ -x "$FETCH_SCRIPT" ]]; then
  info "Running sysfetch.sh..."
  "$FETCH_SCRIPT"
else
  warn "macfetch.sh not found or not executable at $FETCH_SCRIPT"
fi

# ─── 5. Prompt to sort files ───────────────────────────────────────────────────

SORT_SCRIPT=~/dev/rafkit/sort-files.sh
echo
read -rp "Would you like to run sort-files.sh? [y/n]" REPLY
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
