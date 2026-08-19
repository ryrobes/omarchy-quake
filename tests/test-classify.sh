#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck disable=SC1091
source "$ROOT/lib/quake-omarchy.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pack() {
  printf 'PACK' >"$1"
  dd if=/dev/zero bs=64 count=1 >>"$1" 2>/dev/null
}

mkdir -p "$tmp/share/id1" "$tmp/classic/id1" "$tmp/re"
pack "$tmp/share/id1/pak0.pak"
pack "$tmp/classic/id1/pak0.pak"
pack "$tmp/classic/id1/pak1.pak"
printf 'not-a-pak' >"$tmp/re/QuakeEX.kpf"

[[ $(qo_classify_basedir "$tmp/share") == shareware ]]
[[ $(qo_classify_basedir "$tmp/classic") == classic ]]
[[ $(qo_classify_basedir "$tmp/re") == rerelease ]]
if qo_classify_basedir "$tmp"; then
  echo "expected unclassified empty dir" >&2
  exit 1
fi

mkdir -p "$tmp/steam/steamapps/common/Quake/Id1"
pack "$tmp/steam/steamapps/common/Quake/Id1/PAK0.PAK"
pack "$tmp/steam/steamapps/common/Quake/Id1/PAK1.PAK"
[[ $(qo_classify_basedir "$tmp/steam/steamapps/common/Quake") == classic ]]

mkdir -p "$tmp/home/.local/share/Steam/steamapps"
cat >"$tmp/home/.local/share/Steam/steamapps/libraryfolders.vdf" <<'VDF'
"libraryfolders"
{
	"0"
	{
		"path"		"STEAMROOT"
	}
	"1"
	{
		"path"		"EXTRALIB"
	}
}
VDF
# Replace placeholders after write
sed -i "s|STEAMROOT|$tmp/steam|g; s|EXTRALIB|$tmp/extra|g" "$tmp/home/.local/share/Steam/steamapps/libraryfolders.vdf"
mkdir -p "$tmp/extra/steamapps/common/Quake/rerelease"
printf 'kpf' >"$tmp/extra/steamapps/common/Quake/rerelease/QuakeEX.kpf"

HOME_BAK=$HOME
HOME=$tmp/home
libs=$(qo_steam_libraries)
HOME=$HOME_BAK
[[ $libs == *"$tmp/extra"* ]] || { echo "steam libraryfolders.vdf not parsed" >&2; echo "$libs" >&2; exit 1; }

linked=$(QO_DATA_DIR=$tmp/data qo_casefold_basedir "$tmp/steam/steamapps/common/Quake")
[[ -L $linked/id1/pak0.pak ]]
[[ -L $linked/id1/pak1.pak ]]
[[ $(qo_classify_basedir "$linked") == classic ]]

[[ $(qo_parse_join 'quake-omarchy join 100.64.1.8:26000') == 100.64.1.8:26000 ]]
[[ $(qo_parse_join '100.64.1.8') == 100.64.1.8:26000 ]]
[[ $(qo_parse_join 'quake://box.tail1234.ts.net:26000') == box.tail1234.ts.net:26000 ]]
[[ $(qo_parse_join 'box') == box:26000 ]]

python3 - "$ROOT/lib/beacon.py" <<'PY'
import importlib.util, sys, socket, threading, time
spec = importlib.util.spec_from_file_location("beacon", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
assert mod.ping_many([], 26001, 0.1) == []
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(("127.0.0.1", 0))
port = sock.getsockname()[1]
payload = {"name": "tester", "map": "e1m2", "port": 26000}
reply = ("%s PONG %s" % (mod.PREFIX, '{"name":"tester","map":"e1m2","port":26000}')).encode()
def serve():
    sock.settimeout(1.5)
    try:
        data, addr = sock.recvfrom(2048)
        sock.sendto(reply, addr)
    except OSError:
        pass
    finally:
        sock.close()
t = threading.Thread(target=serve, daemon=True)
t.start()
found = mod.ping_many(["127.0.0.1"], port, 0.8, exclude=["10.0.0.1"])
assert found and found[0]["name"] == "tester", found
hidden = mod.ping_many(["127.0.0.1"], port, 0.2, exclude=["127.0.0.1"])
assert hidden == [], hidden
print("beacon ping: ok")
PY

QO_STATE_DIR=$tmp/state
mkdir -p "$QO_STATE_DIR"
printf '%s\n' '{"version":1,"mode":"play","running":true,"pid":999999999}' >"$QO_STATE_DIR/status.json"
qo_status_reap
python3 - "$QO_STATE_DIR/status.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data.get("running") is False, data
assert data.get("mode") == "idle", data
assert data.get("pid") is None, data
PY

[[ $(qo_sanitize_player_name 'ryanr') == ryanr ]]
[[ $(qo_sanitize_player_name 'thisnameistoolongforquake') == thisnameistoolo ]]
[[ $(qo_sanitize_player_name 'bad"quote') == badquote ]]
[[ $(qo_clamp_color 4) == 4 ]]
[[ $(qo_clamp_color 99) == 13 ]]
[[ $(qo_clamp_color -1) == 0 ]]
[[ $(qo_clamp_color nope) == 0 ]]

QO_CONFIG_DIR=$tmp/cfg
mkdir -p "$QO_CONFIG_DIR"
USER=tester qo_config_load
[[ $QO_CFG_NAME == tester ]]
qo_config_set name 'frag"lord'
[[ $QO_CFG_NAME == fraglord ]]
qo_config_set shirt 4
qo_config_set pants 13
grep -q '^name=fraglord$' "$QO_CONFIG_DIR/config"
grep -q '^shirt=4$' "$QO_CONFIG_DIR/config"
grep -q '^pants=13$' "$QO_CONFIG_DIR/config"

[[ $(qo_data_origin /working/SteamLibrary/steamapps/common/Quake/rerelease) == steam ]]
share_dir=$tmp/data/shareware
mkdir -p "$share_dir"
[[ $(QO_DATA_DIR=$tmp/data qo_data_origin "$share_dir") == shareware ]]

maps_json=$(qo_maps_print auto)
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert isinstance(d,list) and "e1m2" in d, d' "$maps_json"
share_maps=$(qo_maps_print shareware)
python3 -c 'import json,sys
d=json.loads(sys.argv[1])
assert "e1m2" in d, d
assert "e2m1" not in d, d
assert "dm2" not in d, d
' "$share_maps"

python3 - "$ROOT/lib/nqctl.py" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("nqctl", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
player = "#%-2u %-16.16s  %3i  %2i:%02i:%02i" % (1, "tester", 3, 0, 1, 23)
sample = "host:    tester\nversion: vkQuake\nmap:     e1m2\nplayers: 1 active (8 max)\n\n%s\n   127.0.0.1:26000\n" % player
info = mod.parse_status(sample)
assert info["ok"] is True, info
assert info["map"] == "e1m2", info
assert info["players"] == 1 and info["max"] == 8, info
assert info["clients"][0]["name"] == "tester", info
assert info["clients"][0]["frags"] == 3, info
assert info["clients"][0]["time"] == "0:01:23", info
spaced = "#%-2u %-16.16s  %3i  %2i:%02i:%02i" % (2, "foo bar", 12, 1, 2, 3)
info2 = mod.parse_status("map:     dm2\nplayers: 1 active (8 max)\n\n%s\n" % spaced)
assert info2["clients"][0]["name"] == "foo bar", info2
assert info2["clients"][0]["frags"] == 12, info2
bad = mod.parse_status("Your password is just WRONG dude.")
assert bad["ok"] is False, bad
print("nqctl parse: ok")
PY

if ( qo_rcon_safe quit ); then
  echo "rcon should reject quit" >&2
  exit 1
fi
if ( qo_rcon_safe map e1m1 ); then
  echo "rcon should reject map (kicks clients)" >&2
  exit 1
fi

QO_ROOT=$ROOT
QO_CONFIG_DIR=$tmp/cfg2
QO_DATA_DIR=$tmp/data2
mkdir -p "$QO_CONFIG_DIR" "$QO_DATA_DIR"
USER=tester qo_config_load
qo_write_video_cfg
grep -q '^rcon_password "' "$QO_DATA_DIR/user/default/id1/omarchy.cfg"
grep -q '^rcon=' "$QO_CONFIG_DIR/config"
[[ -n $QO_CFG_RCON ]]
[[ ${#QO_CFG_RCON} -eq 16 ]]
host_json=$(qo_host_status)
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert "ok" in d, d' "$host_json"

[[ $(qo_next_map_name 1 e1m2 '["e1m1","e1m2","dm2"]') == dm2 ]]
[[ $(qo_next_map_name 1 dm2 '["e1m1","e1m2","dm2"]') == e1m1 ]]
[[ $(qo_next_map_name -1 e1m1 '["e1m1","e1m2","dm2"]') == dm2 ]]
[[ $(qo_next_map_name 1 missing '["e1m1","e1m2"]') == e1m1 ]]
[[ $(qo_next_map_name -1 missing '["e1m1","e1m2"]') == e1m2 ]]
if qo_changelevel_delta 1; then
  echo "next-map should fail when no server is up" >&2
  exit 1
fi

mkdir -p "$tmp/cfg3"
cat >"$tmp/cfg3/vkQuake.cfg" <<'CFG'
unbindall
sensitivity "3"
vid_fullscreen "1"
vid_restart
+mlook
CFG
qo_sanitize_vkquake_cfg "$tmp/cfg3/vkQuake.cfg"
! grep -q '^unbindall' "$tmp/cfg3/vkQuake.cfg"
! grep -q '^vid_restart' "$tmp/cfg3/vkQuake.cfg"
grep -q '^sensitivity' "$tmp/cfg3/vkQuake.cfg"
grep -q '^+mlook' "$tmp/cfg3/vkQuake.cfg"
grep -q '^r_rtshadows "0"' "$tmp/cfg3/vkQuake.cfg"

echo "test-classify: ok"
