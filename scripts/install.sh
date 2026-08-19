#!/usr/bin/env bash
# Install Quake into the current Omarchy user session.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PREFIX=${PREFIX:-$HOME/.local}
PLUGIN_ID=quake.omarchy
PLUGIN_DEST=${PLUGIN_DEST:-$HOME/.config/omarchy/plugins/$PLUGIN_ID}

log() { printf 'quake-omarchy: %s\n' "$*"; }

need() {
  command -v "$1" >/dev/null || {
    echo "missing dependency: $1" >&2
    exit 1
  }
}

need meson
need ninja
need curl
need python3

if ! command -v 7z >/dev/null && ! command -v unzip >/dev/null; then
  echo "need 7z or unzip to extract shareware" >&2
  exit 1
fi

ENGINE_BUILD=$ROOT/build/engine
bash "$ROOT/scripts/build-engine.sh"
[[ -x $ENGINE_BUILD/vkquake ]] || { echo "vkquake build failed" >&2; exit 1; }

log "installing launcher to $PREFIX"
mkdir -p "$PREFIX/bin" "$PREFIX/lib/quake-omarchy/lib"

install -m 0755 "$ROOT/bin/quake-omarchy" "$PREFIX/bin/quake-omarchy"
install -m 0644 "$ROOT/lib/quake-omarchy.sh" "$PREFIX/lib/quake-omarchy/lib/quake-omarchy.sh"
install -m 0755 "$ROOT/lib/beacon.py" "$PREFIX/lib/quake-omarchy/lib/beacon.py"
install -m 0755 "$ROOT/lib/nqctl.py" "$PREFIX/lib/quake-omarchy/lib/nqctl.py"
install -m 0755 "$ENGINE_BUILD/vkquake" "$PREFIX/lib/quake-omarchy/vkquake"
DESKTOP_DIR=$HOME/.local/share/applications
ICON_BASE=$HOME/.local/share/icons/hicolor
FONT_DIR=$HOME/.local/share/fonts
mkdir -p "$DESKTOP_DIR" \
  "$ICON_BASE/scalable/apps" \
  "$ICON_BASE/128x128/apps" \
  "$FONT_DIR" \
  "$HOME/.local/share/quake-omarchy"
install -m 0644 "$ROOT/plugin/quake-logo.svg" \
  "$HOME/.local/share/quake-omarchy/quake-logo.svg"
if [[ -f $ROOT/share/QuakeQuattro.otf ]]; then
  install -m 0644 "$ROOT/share/QuakeQuattro.otf" "$FONT_DIR/QuakeQuattro.otf"
  fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
fi
bash "$ROOT/scripts/recolor-quake-icon.sh" || true
bash "$ROOT/scripts/cleanup-launchers.sh" || true
ICON_SVG=$ICON_BASE/scalable/apps/org.omarchy.quake.svg
cat >"$DESKTOP_DIR/org.omarchy.quake.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Quake
GenericName=Quake
Comment=Quake 1 for Omarchy — shareware, classic, or 2021 re-release
Exec=$PREFIX/bin/quake-omarchy panel
Icon=$ICON_SVG
Terminal=false
Categories=Game;
StartupNotify=true
StartupWMClass=org.omarchy.quake
X-QuakeOmarchy-Managed=true
EOF

log "installing Omarchy plugin"
mkdir -p "$PLUGIN_DEST"
# Do not use cp -a: preserved mtimes let Quickshell keep a stale Panel.qml.
find "$PLUGIN_DEST" -maxdepth 1 -type f -name '*.qml' -delete
cp -f "$ROOT/plugin/"* "$PLUGIN_DEST/" 2>/dev/null || cp -f "$ROOT/plugin/." "$PLUGIN_DEST/"
touch "$PLUGIN_DEST"/*.qml "$PLUGIN_DEST"/*.js "$PLUGIN_DEST"/manifest.json 2>/dev/null || true
if command -v omarchy-plugin-validate >/dev/null; then
  omarchy-plugin-validate "$PLUGIN_DEST"
fi

HYPR_APPS=$HOME/.config/hypr/apps
HYPR_LUA=$HOME/.config/hypr/hyprland.lua
mkdir -p "$HYPR_APPS"
install -m 0644 "$ROOT/hypr/quake-omarchy.lua" "$HYPR_APPS/quake-omarchy.lua"
if [[ -f $HYPR_LUA ]] && ! grep -q 'hypr.apps.quake-omarchy' "$HYPR_LUA"; then
  cp "$HYPR_LUA" "$HYPR_LUA.bak.$(date +%s)"
  python3 - "$HYPR_LUA" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
line = 'require("hypr.apps.quake-omarchy")\n'
if "hypr.apps.quake-omarchy" in text:
    raise SystemExit(0)
needle = 'require("hypr.apps.synchro")\n'
if needle in text:
    text = text.replace(needle, needle + line, 1)
else:
    needle = 'require("hypr.autostart")\n'
    if needle in text:
        text = text.replace(needle, needle + line, 1)
    else:
        text += "\n" + line
path.write_text(text)
PY
  log "wired Hyprland rules into ~/.config/hypr/hyprland.lua"
fi

MENU=$HOME/.config/omarchy/extensions/omarchy-menu.jsonc
mkdir -p "$(dirname "$MENU")"
python3 - "$MENU" <<'PY'
from pathlib import Path
import json, re, sys

path = Path(sys.argv[1])
raw = path.read_text() if path.exists() else "{\n}\n"
stripped = re.sub(r"^\s*//.*?$", "", raw, flags=re.M)
stripped = re.sub(r",(\s*[}\]])", r"\1", stripped)
try:
    data = json.loads(stripped)
except json.JSONDecodeError:
    data = {}
if not isinstance(data, dict):
    data = {}
if "games" not in data:
    data["games"] = {"icon": "", "label": "Games"}
data.pop("games.quake-setup", None)
data["games.quake"] = {
    "icon": "Q",
    "iconFont": "QuakeQuattro",
    "label": "Quake",
    "action": "quake-omarchy panel",
    "description": "Play, host, or join",
}
data["games.quake-host"] = {
    "icon": "Q",
    "iconFont": "QuakeQuattro",
    "label": "Host game",
    "action": "quake-omarchy host",
    "description": "Start a server. Super+Shift+Q changes maps in-match",
}
data["games.quake-join"] = {
    "icon": "Q",
    "iconFont": "QuakeQuattro",
    "label": "Join game",
    "action": "quake-omarchy join",
    "description": "Clipboard, then LAN or Tailscale",
}
header = "// Extend the Quickshell Omarchy menu with JSONC.\n"
path.write_text(header + json.dumps(data, indent=2, ensure_ascii=False) + "\n")
PY
log "added Games ▸ Quake to the Omarchy menu"

if command -v omarchy >/dev/null; then
  omarchy hook install theme-set "$ROOT/scripts/recolor-quake-icon.sh" >/dev/null 2>&1 || true
fi

if command -v update-desktop-database >/dev/null; then
  update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
fi
gtk-update-icon-cache -f "$ICON_BASE" >/dev/null 2>&1 || true

if command -v omarchy-shell >/dev/null; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  omarchy-shell shell enablePlugin "$PLUGIN_ID" '{}' >/dev/null 2>&1 || \
    omarchy plugin enable "$PLUGIN_ID" >/dev/null 2>&1 || true
fi
# Quickshell keeps Panel.qml in memory across cp. Restart so this machine
# and the next `make install` on another host actually show the new panel.
if command -v omarchy >/dev/null; then
  log "restarting Omarchy shell so the panel is not stale"
  omarchy restart shell >/dev/null 2>&1 || true
fi

if command -v hyprctl >/dev/null; then
  hyprctl reload >/dev/null 2>&1 || true
  hyprctl configerrors || true
fi

log "installed. Play with: quake-omarchy"
log "or Super+Space → Games → Quake. First run downloads shareware (~18MB)."
