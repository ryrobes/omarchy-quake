#!/usr/bin/env bash
# Install omarchy-quake.
#
# Developer:  make install                 (PREFIX=$HOME/.local, user plugin/hypr)
# Package:    DESTDIR=$pkgdir PREFIX=/usr SKIP_BUILD=1
#
# DESTDIR or PREFIX outside $HOME never writes to the installing user's home.
# The Omarchy menu stub (Install > Gaming) copies the plugin into
# ~/.config/omarchy/plugins after pacman; this script only ships the files.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PREFIX=${PREFIX:-$HOME/.local}
DESTDIR=${DESTDIR:-}
PREFIX=${PREFIX%/}
DESTDIR=${DESTDIR%/}

PLUGIN_ID=quake.omarchy
PKG_LIB=omarchy-quake

log() { printf 'omarchy-quake: %s\n' "$*"; }

need() {
  command -v "$1" >/dev/null || {
    echo "missing dependency: $1" >&2
    exit 1
  }
}

need python3

ENGINE=${QO_ENGINE:-$ROOT/build/engine/vkquake}
if [[ ${SKIP_BUILD:-0} != 1 ]]; then
  bash "$ROOT/scripts/build-engine.sh"
  ENGINE=$ROOT/build/engine/vkquake
fi
[[ -x $ENGINE ]] || {
  echo "vkquake is missing at $ENGINE (build first, or set QO_ENGINE / SKIP_BUILD=0)" >&2
  exit 1
}

user_integration=0
if [[ -z $DESTDIR && ( $PREFIX == "$HOME" || $PREFIX == "$HOME"/* ) ]]; then
  user_integration=1
fi
case ${INSTALL_USER_INTEGRATION:-} in
  1 | yes | true) user_integration=1 ;;
  0 | no | false) user_integration=0 ;;
esac

BINDIR=$DESTDIR$PREFIX/bin
LIBDIR=$DESTDIR$PREFIX/lib/$PKG_LIB
SHAREDIR=$DESTDIR$PREFIX/share/$PKG_LIB
APPDIR=$DESTDIR$PREFIX/share/applications
ICONDIR=$DESTDIR$PREFIX/share/icons/hicolor

log "installing to ${DESTDIR:+$DESTDIR}$PREFIX"
mkdir -p "$BINDIR" "$LIBDIR/lib" "$SHAREDIR/plugin" "$SHAREDIR/hypr" \
  "$APPDIR" "$ICONDIR/scalable/apps"

install -m 0755 "$ROOT/bin/omarchy-quake" "$BINDIR/omarchy-quake"
rm -f "$BINDIR/quake-omarchy"
install -m 0644 "$ROOT/lib/quake-omarchy.sh" "$LIBDIR/lib/quake-omarchy.sh"
install -m 0755 "$ROOT/lib/beacon.py" "$LIBDIR/lib/beacon.py"
install -m 0755 "$ROOT/lib/nqctl.py" "$LIBDIR/lib/nqctl.py"
install -m 0755 "$ENGINE" "$LIBDIR/vkquake"
install -m 0644 "$ROOT/hypr/quake-omarchy.lua" "$SHAREDIR/hypr/quake.lua"
install -m 0644 "$ROOT/plugin/quake-logo.svg" "$SHAREDIR/quake-logo.svg"
install -m 0644 "$ROOT/share/org.omarchy.quake.svg" \
  "$ICONDIR/scalable/apps/org.omarchy.quake.svg"

# Plugin files only (no nested symlinks — omarchy-plugin-validate forbids them).
find "$SHAREDIR/plugin" -mindepth 1 -delete
cp -f "$ROOT/plugin/"* "$SHAREDIR/plugin/"
# Desktop is PATH-based; ship it at the XDG location, not only inside the plugin.
install -m 0644 "$ROOT/plugin/org.omarchy.quake.desktop" \
  "$APPDIR/org.omarchy.quake.desktop"
install -Dm644 "$ROOT/LICENSE" "$DESTDIR$PREFIX/share/licenses/$PKG_LIB/LICENSE"
if [[ -f $ROOT/vendor/vkQuake/LICENSE.txt ]]; then
  install -Dm644 "$ROOT/vendor/vkQuake/LICENSE.txt" \
    "$DESTDIR$PREFIX/share/licenses/$PKG_LIB/vkQuake-LICENSE.txt"
fi

if (( user_integration )); then
  PLUGIN_DEST=${PLUGIN_DEST:-$HOME/.config/omarchy/plugins/$PLUGIN_ID}
  DESKTOP_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/applications
  ICON_BASE=${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor
  mkdir -p "$PLUGIN_DEST" "$DESKTOP_DIR" \
    "$ICON_BASE/scalable/apps" "$ICON_BASE/128x128/apps" \
    "$HOME/.local/share/quake-omarchy"

  find "$PLUGIN_DEST" -maxdepth 1 -type f -name '*.qml' -delete
  cp -f "$ROOT/plugin/"* "$PLUGIN_DEST/"
  touch "$PLUGIN_DEST"/*.qml "$PLUGIN_DEST"/*.js "$PLUGIN_DEST"/manifest.json 2>/dev/null || true
  if command -v omarchy-plugin-validate >/dev/null; then
    omarchy-plugin-validate "$PLUGIN_DEST"
  fi

  # Older installs shipped a placeholder font; drop it.
  rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/fonts/QuakeQuattro.otf"
  install -m 0644 "$ROOT/plugin/quake-logo.svg" \
    "$HOME/.local/share/quake-omarchy/quake-logo.svg"
  QUAKE_LOGO_SVG=$HOME/.local/share/quake-omarchy/quake-logo.svg \
    bash "$ROOT/scripts/recolor-quake-icon.sh" || true
  bash "$ROOT/scripts/cleanup-launchers.sh" || true

  # Keep a user desktop that calls PATH, even if PREFIX is ~/.local.
  install -m 0644 "$ROOT/plugin/org.omarchy.quake.desktop" \
    "$DESKTOP_DIR/org.omarchy.quake.desktop"

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
for needle in ('require("hypr.apps.synchro")\n', 'require("hypr.autostart")\n'):
    if needle in text:
        path.write_text(text.replace(needle, needle + line, 1))
        raise SystemExit(0)
path.write_text(text + "\n" + line)
PY
    log "wired Hyprland rules into ~/.config/hypr/hyprland.lua"
  fi

  if command -v omarchy >/dev/null; then
    omarchy hook install theme-set "$ROOT/scripts/recolor-quake-icon.sh" >/dev/null 2>&1 || true
  fi
  if command -v update-desktop-database >/dev/null; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi
  gtk-update-icon-cache -f "$ICON_BASE" >/dev/null 2>&1 || true

  if [[ ${SKIP_SESSION:-0} != 1 ]]; then
    if command -v omarchy-shell >/dev/null; then
      omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
      omarchy-shell shell enablePlugin "$PLUGIN_ID" '{}' >/dev/null 2>&1 || \
        omarchy plugin enable "$PLUGIN_ID" >/dev/null 2>&1 || true
    fi
    if command -v omarchy >/dev/null; then
      log "restarting Omarchy shell so the panel is not stale"
      omarchy restart shell >/dev/null 2>&1 || true
    fi
    if command -v hyprctl >/dev/null; then
      hyprctl reload >/dev/null 2>&1 || true
      hyprctl configerrors || true
    fi
  fi
fi

log "installed. Play with: omarchy-quake"
if (( user_integration )); then
  log "or Super+Space and type Quake. First run downloads shareware (~18MB)."
else
  log "package tree only; enable plugin quake.omarchy from the Omarchy installer."
fi
