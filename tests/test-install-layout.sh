#!/usr/bin/env bash
# DESTDIR layout for the omarchy-quake package. Does not compile vkQuake.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fake=$tmp/vkquake
printf '#!/bin/bash\nexit 0\n' >"$fake"
chmod +x "$fake"

home=$tmp/home
mkdir -p "$home"
pkg=$tmp/pkg

HOME=$home DESTDIR=$pkg PREFIX=/usr SKIP_BUILD=1 QO_ENGINE=$fake \
  bash "$ROOT/scripts/install.sh"

desktop=$pkg/usr/share/applications/org.omarchy.quake.desktop
plugin=$pkg/usr/share/omarchy-quake/plugin
lib=$pkg/usr/lib/omarchy-quake

[[ -x $pkg/usr/bin/omarchy-quake ]]
[[ ! -e $pkg/usr/bin/quake-omarchy ]]
[[ -x $lib/vkquake ]]
[[ -f $lib/lib/quake-omarchy.sh ]]
[[ -f $lib/lib/beacon.py ]]
[[ -f $lib/lib/nqctl.py ]]
[[ -f $plugin/manifest.json ]]
[[ -f $plugin/Panel.qml ]]
[[ -f $plugin/Service.qml ]]
[[ -f $plugin/SignalBackdrop.qml ]]
[[ -f $plugin/icon.svg ]]
[[ ! -e $plugin/demo-loop.mp4 ]]
[[ ! -e $plugin/quake-logo.svg ]]
[[ ! -e $plugin/quake-logo-outline.svg ]]
[[ -f $pkg/usr/share/omarchy-quake/hypr/quake.lua ]]
[[ -f $pkg/usr/share/icons/hicolor/scalable/apps/org.omarchy.quake.svg ]]
[[ -f $desktop ]]
[[ -f $pkg/usr/share/licenses/omarchy-quake/LICENSE ]]
grep -qx 'Exec=omarchy-quake panel' "$desktop"
grep -qx 'Icon=org.omarchy.quake' "$desktop"
grep -qx 'Name=Quake' "$desktop"
cmp "$plugin/icon.svg" "$pkg/usr/share/icons/hicolor/scalable/apps/org.omarchy.quake.svg"
if grep -RFl 'QtMultimedia\|demo-loop\.mp4\|quake-logo' "$pkg/usr/share/omarchy-quake" 2>/dev/null; then
  echo "package tree contains removed third-party visual references" >&2
  exit 1
fi

# Packaging must not touch $HOME (plugin enable is the Omarchy installer).
if [[ -e $home/.config || -e $home/.local ]]; then
  echo "DESTDIR install wrote to HOME=$home" >&2
  find "$home" -print >&2
  exit 1
fi
if grep -RFl 'games.quake' "$pkg/usr/bin" "$pkg/usr/share" "$pkg/usr/lib/omarchy-quake/lib" 2>/dev/null; then
  echo "package tree still mentions games.quake menu ids" >&2
  exit 1
fi

# User-prefix install still copies the plugin for local development.
user=$tmp/user
mkdir -p "$user/.config/omarchy/plugins/quake.omarchy" "$user/.local/share/quake-omarchy"
touch "$user/.config/omarchy/plugins/quake.omarchy/demo-loop.mp4" \
  "$user/.config/omarchy/plugins/quake.omarchy/quake-logo.svg" \
  "$user/.config/omarchy/plugins/quake.omarchy/quake-logo-outline.svg" \
  "$user/.local/share/quake-omarchy/quake-logo.svg"
HOME=$user PREFIX=$user/.local SKIP_BUILD=1 QO_ENGINE=$fake \
  SKIP_SESSION=1 \
  bash "$ROOT/scripts/install.sh" >/dev/null
[[ -x $user/.local/bin/omarchy-quake ]]
[[ ! -e $user/.local/bin/quake-omarchy ]]
[[ -f $user/.config/omarchy/plugins/quake.omarchy/Panel.qml ]]
[[ -f $user/.local/share/applications/org.omarchy.quake.desktop ]]
[[ ! -e $user/.config/omarchy/plugins/quake.omarchy/demo-loop.mp4 ]]
[[ ! -e $user/.config/omarchy/plugins/quake.omarchy/quake-logo.svg ]]
[[ ! -e $user/.config/omarchy/plugins/quake.omarchy/quake-logo-outline.svg ]]
[[ ! -e $user/.local/share/quake-omarchy/quake-logo.svg ]]
if [[ -f $user/.config/omarchy/extensions/omarchy-menu.jsonc ]] &&
  grep -q 'games.quake' "$user/.config/omarchy/extensions/omarchy-menu.jsonc"; then
  echo "user install injected games.quake into the menu overlay" >&2
  exit 1
fi

# Leftover Games rows from older make install are stripped.
mkdir -p "$user/.config/omarchy/extensions"
cat >"$user/.config/omarchy/extensions/omarchy-menu.jsonc" <<'JSON'
{
  "games": {"icon": "x", "label": "Games"},
  "games.quake": {"label": "Quake"}
}
JSON
HOME=$user bash "$ROOT/scripts/cleanup-launchers.sh"
if grep -q 'games' "$user/.config/omarchy/extensions/omarchy-menu.jsonc"; then
  echo "cleanup left games.quake menu rows" >&2
  cat "$user/.config/omarchy/extensions/omarchy-menu.jsonc" >&2
  exit 1
fi

echo "ok test-install-layout"
