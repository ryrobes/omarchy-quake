#!/usr/bin/env bash
# Recolor the Quake Q to the active Omarchy foreground (transparent background).
# Installed as a theme-set hook so app-launcher icons follow the theme.
set -euo pipefail

THEME_DIR=${OMARCHY_CURRENT_THEME:-${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current/theme}
SRC=${QUAKE_LOGO_SVG:-}
if [[ -z $SRC ]]; then
  for candidate in \
    "$HOME/.local/share/quake-omarchy/quake-logo.svg" \
    "$HOME/.config/omarchy/plugins/quake.omarchy/quake-logo.svg"
  do
    [[ -f $candidate ]] && SRC=$candidate && break
  done
fi
[[ -f ${SRC:-} ]] || exit 0

OUT_SVG=$HOME/.local/share/icons/hicolor/scalable/apps/org.omarchy.quake.svg
OUT_PNG=$HOME/.local/share/icons/hicolor/128x128/apps/org.omarchy.quake.png
mkdir -p "$(dirname "$OUT_SVG")" "$(dirname "$OUT_PNG")"

color=$(python3 - "$THEME_DIR/colors.toml" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
color = "#CDD6BF"
if path.is_file():
    for line in path.read_text().splitlines():
        line = line.strip()
        if line.startswith("foreground") and "=" in line:
            color = line.split("=", 1)[1].strip().strip('"').strip("'")
            break
print(color)
PY
)

python3 - "$SRC" "$OUT_SVG" "$color" <<'PY'
from pathlib import Path
import re, sys
src, dest, color = sys.argv[1], sys.argv[2], sys.argv[3]
text = Path(src).read_text()
text = re.sub(r'fill="[^"]*"', f'fill="{color}"', text, count=1)
if 'fill="' not in text:
    text = text.replace("<path ", f'<path fill="{color}" ', 1)
Path(dest).write_text(text)
PY

if command -v rsvg-convert >/dev/null; then
  rsvg-convert -w 128 -h 128 "$OUT_SVG" -o "$OUT_PNG" >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null; then
  gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
fi
