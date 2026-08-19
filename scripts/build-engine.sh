#!/usr/bin/env bash
# Clone vkQuake if needed and compile it for this tree.
# Ignores a copied build/ directory from another machine (Meson bakes in
# absolute source paths).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=$ROOT/vendor/vkQuake
BUILD=$ROOT/build/engine
VKQUAKE_REPO=${VKQUAKE_REPO:-https://github.com/Novum/vkQuake.git}
VKQUAKE_REF=${VKQUAKE_REF:-1.35.0}

log() { printf 'omarchy-quake: %s\n' "$*"; }

need() {
  command -v "$1" >/dev/null || {
    echo "missing dependency: $1" >&2
    echo "On Omarchy: omarchy pkg add base-devel git meson ninja pkgconf sdl3 vulkan-headers vulkan-icd-loader glslang spirv-tools mpg123 libvorbis flac opus libogg p7zip" >&2
    exit 1
  }
}

need git
need meson
need ninja

if [[ ! -f $SRC/meson.build ]]; then
  log "cloning vkQuake ${VKQUAKE_REF}"
  rm -rf "$SRC"
  mkdir -p "$(dirname "$SRC")"
  if ! git clone --depth 1 --branch "$VKQUAKE_REF" "$VKQUAKE_REPO" "$SRC"; then
    log "tag ${VKQUAKE_REF} missing, cloning default branch"
    rm -rf "$SRC"
    git clone --depth 1 "$VKQUAKE_REPO" "$SRC"
  fi
fi
[[ -f $SRC/meson.build ]] || {
  echo "vkQuake source is missing meson.build at $SRC" >&2
  exit 1
}

# Tiny deltas on stock vkQuake (Wayland quit idle, window title). Re-clone
# of vendor/vkQuake drops in-tree edits, so re-apply from patches/vkquake.
apply_engine_patches() {
  local patchdir=$ROOT/patches/vkquake
  local p
  [[ -d $patchdir ]] || return 0
  for p in "$patchdir"/*.patch; do
    [[ -f $p ]] || continue
    if (cd "$SRC" && git apply --check "$p") >/dev/null 2>&1; then
      log "applying $(basename "$p")"
      (cd "$SRC" && git apply "$p")
    elif (cd "$SRC" && git apply --reverse --check "$p") >/dev/null 2>&1; then
      log "already applied $(basename "$p")"
    else
      echo "failed to apply $(basename "$p") onto $SRC" >&2
      (cd "$SRC" && git apply --check "$p") || true
      exit 1
    fi
  done
}
apply_engine_patches

meson_source=""
if [[ -f $BUILD/meson-info/meson-info.json ]]; then
  meson_source=$(python3 -c 'import json,sys
try:
    print(json.load(open(sys.argv[1]))["directories"]["source"])
except Exception:
    pass
' "$BUILD/meson-info/meson-info.json")
fi

if [[ -d $BUILD ]] && [[ $meson_source != "$SRC" || ! -f $SRC/meson.build ]]; then
  log "discarding stale engine build (was configured for ${meson_source:-unknown host})"
  rm -rf "$BUILD"
fi

if [[ ! -f $BUILD/build.ninja ]]; then
  log "configuring vkQuake"
  meson setup "$BUILD" "$SRC" -Duse_sdl3=enabled -Ddo_userdirs=enabled --buildtype=release
fi

log "compiling vkQuake"
ninja -C "$BUILD"
[[ -x $BUILD/vkquake ]] || {
  echo "vkquake binary was not produced at $BUILD/vkquake" >&2
  exit 1
}
