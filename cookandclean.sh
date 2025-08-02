#!/usr/bin/env bash
set -euo pipefail

# 1. Homebrew update & cleanup
echo "🛠  Updating Homebrew..."
brew update
brew upgrade
brew upgrade --cask
brew cleanup
brew link --overwrite node

# 2. NPM global packages
if command -v npm >/dev/null 2>&1; then
  echo "📦  Updating npm global packages..."
  npm update -g
  npm cache clean --force
fi

# 3. Yarn global packages
if command -v yarn >/dev/null 2>&1; then
  echo "📦  Updating Yarn global packages..."
  yarn global upgrade
  yarn cache clean
fi

# 4. PNPM global packages
if command -v pnpm >/dev/null 2>&1; then
  echo "📦  Updating PNPM global packages..."
  pnpm update -g
  pnpm store prune
fi

# 5. Pipx packages
if command -v pipx >/dev/null 2>&1; then
  echo "🐍  Upgrading pipx packages..."
  pipx upgrade-all
fi

# 6. General macOS clean-up
echo "🧹  Cleaning macOS caches..."
rm -rf ~/Library/Caches/*
echo "🗑  Emptying Trash..."
rm -rf ~/.Trash/*

# 7. Run macfetch
echo "⚙️   Running macfetch.sh"
if [[ -x ~/dev/rafkit/macfetch.sh ]]; then
  ~/dev/rafkit/macfetch.sh
else
  echo "⚠️  Warning: ~/dev/rafkit/macfetch.sh not found or not executable"
fi

# 8. Prompt to run sort-files
read -rp "❓  Would you like to run sort-files.sh -v? [y/N] " run_sort
if [[ "$run_sort" =~ ^[Yy]$ ]]; then
  if [[ -x ~/dev/rafkit/sort-files.sh ]]; then
    echo "🚚  Running sort-files.sh -v"
    ~/dev/rafkit/sort-files.sh -v
  else
    echo "⚠️  Warning: ~/dev/rafkit/sort-files.sh not found or not executable"
  fi
else
  echo "⏭  Skipping sort-files."
fi

echo "✅  All done!"
