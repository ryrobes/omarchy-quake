#!/usr/bin/env bash
# Remove leftover Quake launcher entries and hide Steam's official Quake
# desktop so Super+Space does not list it next to ours.
set -euo pipefail

APPS=${XDG_DATA_HOME:-$HOME/.local/share}/applications
mkdir -p "$APPS"

# Steam writes ~/.local/share/applications/Quake.desktop (rungameid/2310).
# Hide it from Omarchy's app list; do not delete — Steam recreates it.
while IFS= read -r -d '' f; do
  if grep -q 'steam://rungameid/2310' "$f" 2>/dev/null; then
    if ! grep -q '^NoDisplay=true' "$f"; then
      printf '\n# Hidden by quake-omarchy so Steam Quake is not a duplicate launcher\nNoDisplay=true\nHidden=true\n' >>"$f"
    fi
  fi
done < <(find "$APPS" -maxdepth 2 -name '*.desktop' -print0 2>/dev/null)

# Names we used to ship
rm -f \
  "$APPS/quake-omarchy.desktop" \
  "$APPS/vkquake.desktop" \
  "$APPS/org.omarchy.vkquake.desktop"

# Drop the old "Quake setup" menu row
MENU=$HOME/.config/omarchy/extensions/omarchy-menu.jsonc
if [[ -f $MENU ]]; then
  python3 - "$MENU" <<'PY'
from pathlib import Path
import json, re, sys
path = Path(sys.argv[1])
raw = path.read_text()
stripped = re.sub(r"^\s*//.*?$", "", raw, flags=re.M)
stripped = re.sub(r",(\s*[}\]])", r"\1", stripped)
try:
    data = json.loads(stripped)
except json.JSONDecodeError:
    raise SystemExit(0)
if not isinstance(data, dict):
    raise SystemExit(0)
changed = False
for key in list(data):
    if key in ("games.quake-setup", "games.quake-play"):
        data.pop(key, None)
        changed = True
    entry = data.get(key)
    if isinstance(entry, dict) and str(entry.get("label") or "") == "Quake Quattro":
        entry["label"] = "Quake"
        changed = True
    if isinstance(entry, dict) and "Quake Quattro" in str(entry.get("description") or ""):
        entry["description"] = "Play, host, or join"
        changed = True
if changed:
    path.write_text("// Extend the Quickshell Omarchy menu with JSONC.\n"
                    + json.dumps(data, indent=2, ensure_ascii=False) + "\n")
PY
fi

if command -v update-desktop-database >/dev/null; then
  update-desktop-database "$APPS" >/dev/null 2>&1 || true
fi
