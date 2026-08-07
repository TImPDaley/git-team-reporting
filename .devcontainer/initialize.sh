#!/usr/bin/env bash
# Runs on the *host* before the container is created (Dev Containers initializeCommand).
# Requires a POSIX shell (Linux/macOS/Codespaces, or WSL on Windows).
set -euo pipefail

if [ -z "${HOME:-}" ]; then
  echo "ERROR: HOME is not set; use WSL (recommended on Windows) so the devcontainer can mount ~/.grok-devcontainer and ~/.config/gh"
  exit 1
fi

require_dir_or_absent() {
  local path="$1"
  local label="$2"
  if [ -e "$path" ] && [ ! -d "$path" ]; then
    echo "ERROR: $path exists but is not a directory ($label); remove or rename it"
    exit 1
  fi
}

require_file_not_dir() {
  local path="$1"
  local label="$2"
  if [ -d "$path" ]; then
    echo "ERROR: $path is a directory ($label); remove it so the path can be a normal file"
    exit 1
  fi
}

# --- GitHub CLI ---
require_dir_or_absent "$HOME/.config" "XDG config"
require_dir_or_absent "$HOME/.config/gh" "GitHub CLI config"
mkdir -p "$HOME/.config/gh"
chmod 700 "$HOME/.config/gh" 2>/dev/null || true

# --- Grok (full directory mount → container /home/vscode/.grok) ---
# IMPORTANT: Do NOT bind-mount auth.json / config.toml as individual *files*.
# Grok's installer and login use atomic rename (mv tmp → target). On Linux,
# renaming over a file mount point fails with "Device or resource busy", which
# breaks install and login after every rebuild.
#
# Host path is ~/.grok-devcontainer (not ~/.grok) so a native host Grok install
# is never mixed with the Linux container binary / state.
GROK_DC="$HOME/.grok-devcontainer"
require_dir_or_absent "$HOME/.grok" "legacy host Grok dir"
require_dir_or_absent "$GROK_DC" "devcontainer Grok home"
mkdir -p "$GROK_DC"
chmod 700 "$GROK_DC" 2>/dev/null || true

# One-time migration from the old per-file mounts under ~/.grok/
# (auth.json / config.toml / sessions) into the new directory mount.
migrate_file() {
  local src="$1"
  local dest="$2"
  if [ -f "$src" ] && [ ! -f "$dest" ]; then
    # Skip empty placeholders created only to satisfy old file mounts.
    if [ -s "$src" ]; then
      cp -a "$src" "$dest"
      echo "Migrated $(basename "$src") → $dest"
    fi
  fi
}

migrate_file "$HOME/.grok/auth.json" "$GROK_DC/auth.json"
migrate_file "$HOME/.grok/config.toml" "$GROK_DC/config.toml"

if [ -d "$HOME/.grok/sessions" ] && [ ! -d "$GROK_DC/sessions" ]; then
  # Copy (not move) so a host-native Grok under ~/.grok keeps its sessions.
  if [ -n "$(ls -A "$HOME/.grok/sessions" 2>/dev/null || true)" ]; then
    mkdir -p "$GROK_DC/sessions"
    cp -a "$HOME/.grok/sessions/." "$GROK_DC/sessions/"
    chmod 700 "$GROK_DC/sessions" 2>/dev/null || true
    echo "Migrated sessions → $GROK_DC/sessions"
  fi
fi

mkdir -p "$GROK_DC/sessions"
chmod 700 "$GROK_DC/sessions" 2>/dev/null || true

# Ensure auth/config are normal files inside the directory (not dirs).
require_file_not_dir "$GROK_DC/auth.json" "Grok auth"
require_file_not_dir "$GROK_DC/config.toml" "Grok config"

echo "initializeCommand OK (Grok dir: $GROK_DC)"
