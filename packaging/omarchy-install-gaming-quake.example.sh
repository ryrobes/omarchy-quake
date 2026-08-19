#!/bin/bash

# omarchy:summary=Install Quake (vkQuake) with the Omarchy panel, then launch it.
# omarchy:requires-sudo=true
#
# Draft for basecamp/omarchy bin/omarchy-install-gaming-quake.
# Copy as-is once omarchy-quake is in the [omarchy] extra repo.

set -euo pipefail

echo "Installing Quake..."
omarchy-pkg-add omarchy-quake

plugin_src=/usr/share/omarchy-quake/plugin
plugin_dest="$HOME/.config/omarchy/plugins/quake.omarchy"
if [[ ! -d $plugin_src ]]; then
  echo "omarchy-quake did not ship $plugin_src" >&2
  exit 1
fi

mkdir -p "$plugin_dest"
# Copy, do not symlink: omarchy-plugin-validate rejects any symlink in a plugin folder.
find "$plugin_dest" -mindepth 1 -delete
cp -f "$plugin_src/"* "$plugin_dest/"
touch "$plugin_dest"/*.qml "$plugin_dest"/*.js "$plugin_dest"/manifest.json

if command -v omarchy-plugin-validate >/dev/null; then
  omarchy-plugin-validate "$plugin_dest"
fi

omarchy-plugin-enable quake.omarchy

hypr_src=/usr/share/omarchy-quake/hypr/quake.lua
hypr_dest="$HOME/.config/hypr/apps/quake-omarchy.lua"
if [[ -f $hypr_src ]]; then
  mkdir -p "$(dirname "$hypr_dest")"
  install -m 0644 "$hypr_src" "$hypr_dest"
fi

if command -v omarchy >/dev/null; then
  omarchy restart shell >/dev/null 2>&1 || true
fi

echo ""
echo "Quake will start now. First launch downloads shareware (~18MB) if you do not already have PAKs."

setsid uwsm-app -- gtk-launch org.omarchy.quake >/dev/null 2>&1 &
