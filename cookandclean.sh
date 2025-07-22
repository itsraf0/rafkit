#!/bin/bash

set -euo pipefail

RUN_SORT=false

for arg in "$@"; do
  case "$arg" in
    -s|--sort)
      RUN_SORT=true
      shift
      ;;
    *)
      # ignore other args
      ;;
  esac
done

echo "🍲 cooking..."

brew update

echo "-> upgrading installed brews..."
brew upgrade

echo "-> upgrading global npm packages..."
npm upgrade -g

echo "🧼 cleaning..."

echo "-> cleaning up Homebrew cache..."
brew cleanup

echo "-> flushing DNS cache..."
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

echo "✅ system cleaned!"

if $RUN_SORT; then
  echo "🚀 [--sort flag detected] running ~/sort-files.sh immediately..."
  ~/sort-files.sh
  exit 0
fi

  ~/dev/rafkit/macfetch.sh

read -t 10 -rp "do you want to run rafsort now? [y/n] " answer \
  || answer="y"

if [[ "$answer" =~ ^[Yy] ]]; then
  echo ""
  echo "🚀 running sort-files.sh..."
  ~/dev/rafkit/sort-files.sh
else
  echo "👍 noted. skipping sort-files for now."
fi
