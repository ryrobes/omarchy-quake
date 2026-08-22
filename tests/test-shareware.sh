#!/usr/bin/env bash
set -euo pipefail
export QO_QUIET=1
ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck disable=SC1091
source "$ROOT/lib/quake-omarchy.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pack() {
  printf 'PACK' >"$1"
  dd if=/dev/zero bs=64 count=1 >>"$1" 2>/dev/null
}

mkdir -p "$tmp/inner/ID1" "$tmp/outer"
pack "$tmp/inner/ID1/PAK0.PAK"
printf '%s\n' 'test shareware agreement' >"$tmp/inner/SLICNSE.TXT"
bsdtar -cf "$tmp/outer/resource.1" -C "$tmp/inner" .
bsdtar -a -cf "$tmp/quake106.zip" -C "$tmp/outer" resource.1
printf '%s\n' 'not the expected archive' >"$tmp/bad.zip"

expected=$(sha256sum "$tmp/quake106.zip" | awk '{print $1}')
QO_SHAREWARE_SHA256=$expected
QO_SHAREWARE_URLS=("file://$tmp/bad.zip" "file://$tmp/quake106.zip")
QO_DATA_DIR=$tmp/data
QO_CACHE_DIR=$tmp/cache
QO_CONFIG_DIR=$tmp/config
QO_STATE_DIR=$tmp/state

qo_fetch_shareware
share=$QO_DATA_DIR/shareware
[[ -f $share/id1/pak0.pak ]]
[[ -f $share/SLICNSE.TXT ]]
cmp "$tmp/inner/SLICNSE.TXT" "$share/SLICNSE.TXT"
python3 - "$QO_STATE_DIR/status.json" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    status = json.load(f)
assert status.get("mode") == "idle", status
assert status.get("fetch") is None, status
PY

# Existing installs from older releases are repaired if the agreement is absent.
rm -f "$share/SLICNSE.TXT"
selected=$(qo_ensure_data shareware)
[[ $selected == "$share" ]]
cmp "$tmp/inner/SLICNSE.TXT" "$share/SLICNSE.TXT"
python3 - "$QO_STATE_DIR/status.json" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    status = json.load(f)
assert status.get("mode") == "idle", status
assert status.get("fetch") is None, status
PY

# A downloaded archive that does not match the pinned digest is never installed.
if (
  QO_DATA_DIR=$tmp/rejected-data
  QO_CACHE_DIR=$tmp/rejected-cache
  QO_CONFIG_DIR=$tmp/rejected-config
  QO_STATE_DIR=$tmp/rejected-state
  QO_SHAREWARE_URLS=("file://$tmp/bad.zip")
  qo_fetch_shareware
) >/dev/null 2>&1; then
  echo "checksum-mismatched shareware archive was accepted" >&2
  exit 1
fi
[[ ! -e $tmp/rejected-data/shareware/id1/pak0.pak ]]

echo "ok test-shareware"
