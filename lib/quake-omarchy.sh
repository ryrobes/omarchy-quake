# Shared library for Quake (omarchy-quake / quake-omarchy).
# Sourced by bin/quake-omarchy. Safe to source from tests.

QO_APP_ID="${QO_APP_ID:-org.omarchy.quake}"
QO_WINDOW_CLASS="${QO_WINDOW_CLASS:-org.omarchy.quake}"
QO_PORT="${QO_PORT:-26000}"
QO_BEACON_PORT="${QO_BEACON_PORT:-26001}"
QO_PLAYERS="${QO_PLAYERS:-8}"
QO_DEFAULT_MAP="${QO_DEFAULT_MAP:-e1m2}"

qo_xdg_home() {
  printf '%s\n' "${HOME:?}"
}

qo_config_dir() {
  printf '%s\n' "${QO_CONFIG_DIR:-${XDG_CONFIG_HOME:-$(qo_xdg_home)/.config}/quake-omarchy}"
}

qo_data_dir() {
  printf '%s\n' "${QO_DATA_DIR:-${XDG_DATA_HOME:-$(qo_xdg_home)/.local/share}/quake-omarchy}"
}

qo_state_dir() {
  printf '%s\n' "${QO_STATE_DIR:-${XDG_STATE_HOME:-$(qo_xdg_home)/.local/state}/quake-omarchy}"
}

qo_cache_dir() {
  printf '%s\n' "${QO_CACHE_DIR:-${XDG_CACHE_HOME:-$(qo_xdg_home)/.cache}/quake-omarchy}"
}

qo_config_file() { printf '%s\n' "$(qo_config_dir)/config"; }
qo_status_file() { printf '%s\n' "$(qo_state_dir)/status.json"; }
qo_session_file() { printf '%s\n' "$(qo_state_dir)/session.env"; }
qo_pid_file() { printf '%s\n' "$(qo_state_dir)/game.pid"; }
# Per-edition userdir so remaster cvars/HUD/config do not leak into
# shareware or classic (and vice versa). Engine path is <userdir>/id1/.
qo_userdir() {
  local ed=${QO_ACTIVE_EDITION:-${QO_CFG_EDITION:-default}}
  case $ed in
    rerelease|remaster|remastered) ed=rerelease ;;
    classic|original|registered) ed=classic ;;
    shareware) ed=shareware ;;
    auto|"") ed=default ;;
  esac
  printf '%s\n' "$(qo_data_dir)/user/$ed"
}
qo_shareware_dir() { printf '%s\n' "$(qo_data_dir)/shareware"; }

qo_mkdirs() {
  mkdir -p "$(qo_config_dir)" "$(qo_data_dir)" "$(qo_state_dir)" "$(qo_cache_dir)" "$(qo_userdir)"
}

qo_json_escape() {
  python3 -c 'import json,sys; sys.stdout.write(json.dumps(sys.argv[1]))' "$1"
}

qo_atomic_write() {
  local dest=$1
  local tmp
  tmp=$(mktemp "${dest}.XXXXXX")
  cat >"$tmp"
  mv -f "$tmp" "$dest"
}

qo_log() {
  printf 'quake-omarchy: %s\n' "$*" >&2
}

qo_die() {
  qo_log "$*"
  qo_status_set error "$*"
  qo_notify "Quake" "$*"
  exit 1
}

# --- config ----------------------------------------------------------------

qo_config_load() {
  QO_CFG_EDITION=auto
  QO_CFG_RENDERER=auto
  QO_CFG_BASEDIR=
  QO_CFG_WINDOWED=false
  QO_CFG_FULLSCREEN=true
  QO_CFG_WIDTH=0
  QO_CFG_HEIGHT=0
  QO_CFG_VSYNC=false
  QO_CFG_PORT=$QO_PORT
  QO_CFG_PLAYERS=$QO_PLAYERS
  QO_CFG_MAP=
  QO_CFG_NAME=$(qo_default_player_name)
  QO_CFG_SHIRT=0
  QO_CFG_PANTS=0
  QO_CFG_RCON=

  local file
  file=$(qo_config_file)
  [[ -f $file ]] || return 0

  local line key value
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line =~ ^[[:space:]]*# ]] && continue
    [[ $line =~ ^[[:space:]]*$ ]] && continue
    key=${line%%=*}
    value=${line#*=}
    case $key in
      edition) QO_CFG_EDITION=$value ;;
      renderer) QO_CFG_RENDERER=$value ;;
      basedir) QO_CFG_BASEDIR=$value ;;
      windowed) QO_CFG_WINDOWED=$value ;;
      fullscreen) QO_CFG_FULLSCREEN=$value ;;
      width) QO_CFG_WIDTH=$value ;;
      height) QO_CFG_HEIGHT=$value ;;
      vsync) QO_CFG_VSYNC=$value ;;
      resolution)
        if [[ $value == native || $value == 0x0 || $value == 0 ]]; then
          QO_CFG_WIDTH=0
          QO_CFG_HEIGHT=0
        elif [[ $value == *x* ]]; then
          QO_CFG_WIDTH=${value%x*}
          QO_CFG_HEIGHT=${value#*x}
        fi
        ;;
      port) QO_CFG_PORT=$value ;;
      players) QO_CFG_PLAYERS=$value ;;
      map) QO_CFG_MAP=$value ;;
      name)
        if [[ -n $value ]]; then
          QO_CFG_NAME=$(qo_sanitize_player_name "$value")
        fi
        ;;
      shirt|topcolor) QO_CFG_SHIRT=$(qo_clamp_color "$value") ;;
      pants|bottomcolor) QO_CFG_PANTS=$(qo_clamp_color "$value") ;;
      rcon) QO_CFG_RCON=$value ;;
    esac
  done <"$file"
  if [[ $QO_CFG_WINDOWED == true ]]; then
    QO_CFG_FULLSCREEN=false
  fi
}

qo_config_set() {
  local key=$1 value=$2
  qo_mkdirs
  qo_config_load
  case $key in
    edition) QO_CFG_EDITION=$value ;;
    renderer) QO_CFG_RENDERER=$value ;;
    basedir) QO_CFG_BASEDIR=$value ;;
    windowed)
      QO_CFG_WINDOWED=$value
      if [[ $value == true ]]; then QO_CFG_FULLSCREEN=false; else QO_CFG_FULLSCREEN=true; fi
      ;;
    fullscreen)
      QO_CFG_FULLSCREEN=$value
      if [[ $value == true ]]; then QO_CFG_WINDOWED=false; else QO_CFG_WINDOWED=true; fi
      ;;
    width) QO_CFG_WIDTH=$value ;;
    height) QO_CFG_HEIGHT=$value ;;
    vsync) QO_CFG_VSYNC=$value ;;
    resolution)
      if [[ $value == native || $value == 0x0 || $value == 0 ]]; then
        QO_CFG_WIDTH=0
        QO_CFG_HEIGHT=0
      elif [[ $value == *x* ]]; then
        QO_CFG_WIDTH=${value%x*}
        QO_CFG_HEIGHT=${value#*x}
      else
        qo_die "resolution must be native or WxH"
      fi
      ;;
    port) QO_CFG_PORT=$value ;;
    players) QO_CFG_PLAYERS=$value ;;
    map) QO_CFG_MAP=$value ;;
    name) QO_CFG_NAME=$(qo_sanitize_player_name "$value") ;;
    shirt|topcolor) QO_CFG_SHIRT=$(qo_clamp_color "$value") ;;
    pants|bottomcolor) QO_CFG_PANTS=$(qo_clamp_color "$value") ;;
    *) qo_die "unknown config key: $key" ;;
  esac
  qo_config_save
}

qo_default_player_name() {
  local n=${USER:-}
  [[ -n $n ]] || n=$(id -un 2>/dev/null || true)
  qo_sanitize_player_name "$n"
}

qo_sanitize_player_name() {
  python3 -c 'import sys
s = sys.argv[1] if len(sys.argv) > 1 else ""
out = []
for ch in s:
    if ch in "\"\\\n\r\t":
        continue
    out.append(ch)
    if len(out) >= 15:
        break
print("".join(out).strip() or "player")
' "${1:-}"
}

qo_clamp_color() {
  python3 -c 'import sys
try:
    n = int(sys.argv[1])
except Exception:
    n = 0
if n < 0: n = 0
if n > 13: n = 13
print(n)
' "${1:-0}"
}

qo_config_save() {
  {
    printf 'edition=%s\n' "$QO_CFG_EDITION"
    printf 'renderer=%s\n' "$QO_CFG_RENDERER"
    printf 'basedir=%s\n' "$QO_CFG_BASEDIR"
    printf 'windowed=%s\n' "$QO_CFG_WINDOWED"
    printf 'fullscreen=%s\n' "$QO_CFG_FULLSCREEN"
    printf 'width=%s\n' "$QO_CFG_WIDTH"
    printf 'height=%s\n' "$QO_CFG_HEIGHT"
    printf 'vsync=%s\n' "$QO_CFG_VSYNC"
    printf 'port=%s\n' "$QO_CFG_PORT"
    printf 'players=%s\n' "$QO_CFG_PLAYERS"
    printf 'map=%s\n' "$QO_CFG_MAP"
    printf 'name=%s\n' "$QO_CFG_NAME"
    printf 'shirt=%s\n' "$QO_CFG_SHIRT"
    printf 'pants=%s\n' "$QO_CFG_PANTS"
    printf 'rcon=%s\n' "$QO_CFG_RCON"
  } | qo_atomic_write "$(qo_config_file)"
}

qo_ensure_rcon_password() {
  if [[ -n ${QO_CFG_RCON:-} ]]; then
    return 0
  fi
  qo_mkdirs
  QO_CFG_RCON=$(python3 -c 'import secrets; print(secrets.token_hex(8))')
  qo_config_save
}

qo_nqctl() {
  printf '%s\n' "${QO_NQCTL:-$QO_ROOT/lib/nqctl.py}"
}

qo_rcon() {
  qo_config_load
  qo_ensure_rcon_password
  python3 "$(qo_nqctl)" --host 127.0.0.1 --port "${QO_CFG_PORT:-26000}" --password "$QO_CFG_RCON" "$@"
}

# NetQuake rcon (CCREQ_RCON), not QuakeWorld. Only the commands a host-admin
# panel needs — `map` is omitted because it kicks every client.
qo_rcon_safe() {
  local verb=${1:-}
  case $verb in
    status)
      qo_rcon "$@"
      ;;
    changelevel)
      [[ $# -eq 2 ]] || qo_die "usage: rcon changelevel <map>"
      [[ $2 =~ ^[A-Za-z0-9_-]+$ ]] || qo_die "bad map name"
      local ed
      ed=$(qo_running_edition || true)
      [[ -n $ed ]] || ed=${QO_CFG_EDITION:-auto}
      qo_map_in_edition "$2" "$ed" || qo_die "map $2 is not in this edition ($ed)"
      qo_rcon "$@"
      QO_CFG_MAP=$2
      qo_config_save
      qo_osd "$2"
      ;;
    say|kick|fraglimit|timelimit|deathmatch|teamplay)
      qo_rcon "$@"
      ;;
    *)
      qo_die "rcon allows status, changelevel, say, kick, fraglimit, timelimit"
      ;;
  esac
}

qo_host_status() {
  qo_config_load
  if [[ -z ${QO_CFG_RCON:-} ]]; then
    printf '%s\n' '{"ok":false,"error":"not hosting"}'
    return 0
  fi
  local out
  out=$(python3 "$(qo_nqctl)" --json --host 127.0.0.1 --port "${QO_CFG_PORT:-26000}" --password "$QO_CFG_RCON" status 2>/dev/null) || true
  if [[ -n $out ]]; then
    printf '%s\n' "$out"
    return 0
  fi
  printf '%s\n' '{"ok":false,"error":"server not ready"}'
}

# Pick the next/previous map from a JSON list. Unknown current map: +1 starts
# at the first entry, -1 at the last.
qo_next_map_name() {
  local delta=$1 current=$2 maps_json=$3
  python3 -c 'import json,sys
delta = int(sys.argv[1])
current = (sys.argv[2] or "").lower()
maps = json.loads(sys.argv[3] or "[]")
maps = [str(m) for m in maps if str(m).strip()]
if not maps:
    raise SystemExit(1)
idx = None
for i, name in enumerate(maps):
    if name.lower() == current:
        idx = i
        break
if idx is None:
    idx = -1 if delta > 0 else 0
print(maps[(idx + delta) % len(maps)])
' "$delta" "$current" "$maps_json"
}

qo_changelevel_delta() {
  local delta=${1:-1}
  local info maps current next
  info=$(qo_host_status)
  python3 -c 'import json,sys; raise SystemExit(0 if json.loads(sys.argv[1]).get("ok") else 1)' "$info" || return 1
  current=$(python3 -c 'import json,sys; print((json.loads(sys.argv[1]) or {}).get("map") or "")' "$info")
  local ed
  ed=$(qo_running_edition || true)
  [[ -n $ed ]] || ed=${QO_CFG_EDITION:-auto}
  maps=$(qo_maps_print "$ed")
  next=$(qo_next_map_name "$delta" "$current" "$maps") || return 1
  qo_rcon_safe changelevel "$next"
}

qo_native_res() {
  hyprctl monitors -j 2>/dev/null | python3 -c 'import json,sys
try:
    mons=json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
for m in mons:
    if m.get("focused"):
        print("%sx%s" % (m.get("width") or 0, m.get("height") or 0))
        raise SystemExit(0)
if mons:
    m=mons[0]
    print("%sx%s" % (m.get("width") or 0, m.get("height") or 0))
' 2>/dev/null || true
}

# vkQuake writes vkQuake.cfg (exec'd as config.cfg) with unbindall and
# vid_restart. An unbindall with no following binds leaves WASD dead; vid_restart
# after 4K/MSAA init can stall 10–20s on host.
qo_sanitize_vkquake_cfg() {
  local cfg=$1
  [[ -f $cfg ]] || return 0
  python3 - "$cfg" <<'PY'
import os, sys
path = sys.argv[1]
try:
    lines = open(path, encoding="latin-1").read().splitlines(True)
except OSError:
    raise SystemExit(0)
has_bind = any(l.lstrip().startswith("bind ") for l in lines)
force = {
    "r_rtshadows": 'r_rtshadows "0"\n',
    "vid_fsaa": 'vid_fsaa "0"\n',
    "vid_desktopfullscreen": 'vid_desktopfullscreen "1"\n',
}
seen = set()
out = []
changed = False
for line in lines:
    stripped = line.strip()
    if stripped == "vid_restart":
        changed = True
        continue
    if stripped == "unbindall" and not has_bind:
        changed = True
        continue
    key = stripped.split(" ", 1)[0].strip('"') if stripped else ""
    if key in force:
        if key not in seen:
            out.append(force[key])
            seen.add(key)
        if stripped != force[key].strip():
            changed = True
        continue
    out.append(line)
for key, repl in force.items():
    if key not in seen:
        out.append(repl)
        changed = True
if changed:
    text = "".join(out)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="latin-1") as f:
        f.write(text)
    os.replace(tmp, path)
PY
}

qo_write_video_cfg() {
  local dir fs w h vs
  dir=$(qo_userdir)/id1
  mkdir -p "$dir"
  fs=0
  vs=0
  [[ $QO_CFG_FULLSCREEN == true && $QO_CFG_WINDOWED != true ]] && fs=1
  [[ $QO_CFG_VSYNC == true ]] && vs=1
  w=$QO_CFG_WIDTH
  h=$QO_CFG_HEIGHT
  if [[ -z $w || $w == 0 || -z $h || $h == 0 ]]; then
    local native
    native=$(qo_native_res)
    if [[ $native == *x* ]]; then
      w=${native%x*}
      h=${native#*x}
    else
      w=1280
      h=720
    fi
  fi
  local name shirt pants rcon
  name=${QO_CFG_NAME:-}
  [[ -n $name ]] || name=$(qo_default_player_name)
  name=$(qo_sanitize_player_name "$name")
  shirt=$(qo_clamp_color "${QO_CFG_SHIRT:-0}")
  pants=$(qo_clamp_color "${QO_CFG_PANTS:-0}")
  qo_ensure_rcon_password
  rcon=$QO_CFG_RCON
  cat >"$dir/omarchy.cfg" <<CFG
vid_fullscreen "$fs"
vid_width "$w"
vid_height "$h"
vid_vsync "$vs"
vid_desktopfullscreen "1"
vid_fsaa "0"
r_rtshadows "0"
host_maxfps "72"
cl_alwaysrun "0"
name "$name"
_cl_name "$name"
topcolor "$shirt"
bottomcolor "$pants"
rcon_password "$rcon"
CFG
  if [[ ! -f $dir/autoexec.cfg ]] || ! grep -q 'exec omarchy.cfg' "$dir/autoexec.cfg" 2>/dev/null; then
    printf '\nexec omarchy.cfg\n' >>"$dir/autoexec.cfg"
  fi
}

# --- pak discovery ---------------------------------------------------------

qo_is_pak() {
  local path=$1
  [[ -f $path ]] || return 1
  [[ $(head -c 4 "$path" 2>/dev/null) == PACK ]]
}

qo_has_kpf() {
  local dir=$1
  local candidate
  for candidate in "$dir/QuakeEX.kpf" "$dir/quakeex.kpf" "$dir/QUAKEEX.KPF"; do
    [[ -f $candidate ]] && return 0
  done
  return 1
}

qo_find_named() {
  local dir=$1 name=$2
  local f
  # Steam/Proton trees mix Id1/PAK0.PAK with id1/pak0.pak.
  while IFS= read -r f; do
    [[ -n $f ]] && printf '%s\n' "$f" && return 0
  done < <(find "$dir" -maxdepth 2 -iname "$name" 2>/dev/null)
  return 1
}

qo_has_pak0() {
  local dir=$1 f
  f=$(qo_find_named "$dir" 'pak0.pak') || return 1
  qo_is_pak "$f"
}

qo_has_pak1() {
  local dir=$1 f
  f=$(qo_find_named "$dir" 'pak1.pak') || return 1
  qo_is_pak "$f"
}

qo_classify_basedir() {
  local dir=$1
  [[ -d $dir ]] || return 1
  if qo_has_kpf "$dir"; then
    printf 'rerelease\n'
    return 0
  fi
  if qo_has_pak1 "$dir"; then
    printf 'classic\n'
    return 0
  fi
  if qo_has_pak0 "$dir"; then
    printf 'shareware\n'
    return 0
  fi
  return 1
}

qo_steam_roots() {
  local home
  home=$(qo_xdg_home)
  local root
  for root in \
    "$home/.local/share/Steam" \
    "$home/.steam/steam" \
    "$home/.steam/root" \
    "$home/.steam/debian-installation" \
    "$home/.var/app/com.valvesoftware.Steam/.local/share/Steam" \
    "$home/.var/app/com.valvesoftware.Steam/data/Steam" \
    "$home/snap/steam/common/.local/share/Steam"
  do
    [[ -d $root ]] && printf '%s\n' "$root"
  done
}

# Every Steam library folder (default install + extra disks from libraryfolders.vdf).
qo_steam_libraries() {
  python3 - "$(qo_xdg_home)" <<'PY'
import os, re, sys
home = sys.argv[1]
roots = [
    os.path.join(home, ".local/share/Steam"),
    os.path.join(home, ".steam/steam"),
    os.path.join(home, ".steam/root"),
    os.path.join(home, ".steam/debian-installation"),
    os.path.join(home, ".var/app/com.valvesoftware.Steam/.local/share/Steam"),
    os.path.join(home, ".var/app/com.valvesoftware.Steam/data/Steam"),
    os.path.join(home, "snap/steam/common/.local/share/Steam"),
]
seen = []

def add(path):
    path = os.path.realpath(os.path.expanduser(path.strip().replace("\\\\", "/")))
    if not path or not os.path.isdir(path) or path in seen:
        return
    seen.append(path)
    print(path)

for root in roots:
    if os.path.isdir(root):
        add(root)
    vdf = os.path.join(root, "steamapps", "libraryfolders.vdf")
    if not os.path.isfile(vdf):
        continue
    try:
        text = open(vdf, errors="replace").read()
    except OSError:
        continue
    for m in re.finditer(r'"path"\s+"([^"]+)"', text):
        add(m.group(1))
    # older: "1"   "/some/library"
    for m in re.finditer(r'"\d+"\s+"(/[^"]+)"', text):
        add(m.group(1))
PY
}

qo_steam_quake_dirs() {
  local lib common
  while IFS= read -r lib; do
    [[ -n $lib ]] || continue
    common="$lib/steamapps/common/Quake"
    [[ -d $common/rerelease ]] && printf '%s\n' "$common/rerelease"
    [[ -d $common ]] && printf '%s\n' "$common"
  done < <(qo_steam_libraries)
}

# vkQuake on Linux wants lowercase id1/pak0.pak. Steam/Proton trees are often Id1/PAK0.PAK.
qo_casefold_basedir() {
  local src=$1
  python3 - "$src" "$(qo_data_dir)/steam-links" <<'PY'
import hashlib, os, sys
src = os.path.realpath(sys.argv[1])
root = sys.argv[2]
if os.path.isfile(os.path.join(src, "id1", "pak0.pak")) or os.path.isfile(os.path.join(src, "QuakeEX.kpf")):
    print(src)
    raise SystemExit(0)
# Only fold game data dirs. Walking Steam's rerelease/ tree on every
# classic launch is tens of seconds and can pull remaster files in.
keep = {"id1", "hipnotic", "rogue", "dopa", "mg1", "ctf"}
digest = hashlib.sha1(src.encode()).hexdigest()[:12]
dest = os.path.join(root, digest)
os.makedirs(dest, exist_ok=True)
for dirpath, dirnames, filenames in os.walk(src):
    rel = os.path.relpath(dirpath, src)
    depth = 0 if rel == "." else rel.count(os.sep) + 1
    if depth == 0:
        dirnames[:] = [d for d in dirnames if d.lower() in keep]
    elif depth > 2:
        dirnames.clear()
        continue
    parts = [] if rel == "." else rel.split(os.sep)
    dest_dir = os.path.join(dest, *[p.lower() for p in parts]) if parts else dest
    os.makedirs(dest_dir, exist_ok=True)
    for name in filenames:
        target = os.path.join(dirpath, name)
        link = os.path.join(dest_dir, name.lower())
        if os.path.lexists(link) and not os.path.islink(link):
            continue
        try:
            if os.path.islink(link) or os.path.exists(link):
                os.remove(link)
        except OSError:
            pass
        os.symlink(target, link)
print(dest)
PY
}

qo_candidate_basedirs() {
  local home
  home=$(qo_xdg_home)
  local seen=()
  emit() {
    local d=$1
    [[ -d $d ]] || return 0
    local real
    real=$(readlink -f "$d" 2>/dev/null || printf '%s' "$d")
    local s
    for s in "${seen[@]+"${seen[@]}"}"; do
      [[ $s == "$real" ]] && return 0
    done
    seen+=("$real")
    printf '%s\n' "$real"
  }

  [[ -n ${QO_CFG_BASEDIR:-} ]] && emit "$QO_CFG_BASEDIR"
  emit "$(qo_shareware_dir)"
  emit "$(qo_data_dir)"
  emit "$home/Games/quake"
  emit "$home/Games/Quake"
  emit "$home/GOG Games/Quake"
  emit "$home/GOG Games/Quake Enhanced"

  local steam_dir
  while IFS= read -r steam_dir; do
    emit "$steam_dir"
  done < <(qo_steam_quake_dirs)

  emit "$home/Games/Heroic/Quake"
  emit "$home/.config/heroic/Prefixes/default/drive_c/Program Files (x86)/Steam/steamapps/common/Quake"
}



# Pure-bash edition listing for the launcher (avoids re-exec).
qo_list_editions() {
  local dir kind
  while IFS= read -r dir; do
    kind=$(qo_classify_basedir "$dir" 2>/dev/null) || continue
    printf '%s\t%s\n' "$kind" "$dir"
  done < <(qo_candidate_basedirs)
}

qo_data_origin() {
  local dir=$1
  local share real lower
  share=$(readlink -f "$(qo_shareware_dir)" 2>/dev/null || true)
  real=$(readlink -f "$dir" 2>/dev/null || printf '%s' "$dir")
  lower=${real,,}
  if [[ -n $share && ( $real == "$share" || $real == "$share"/* ) ]]; then
    printf 'shareware\n'
  elif [[ $lower == *steamapps* || $lower == *steamlibrary* ]]; then
    printf 'steam\n'
  elif [[ $lower == *'/gog games/'* || $lower == *'/gog/'* ]]; then
    printf 'gog\n'
  elif [[ $lower == *heroic* ]]; then
    printf 'heroic\n'
  elif [[ -n ${QO_CFG_BASEDIR:-} ]]; then
    local imported
    imported=$(readlink -f "$QO_CFG_BASEDIR" 2>/dev/null || printf '%s' "$QO_CFG_BASEDIR")
    if [[ $imported == "$real" ]]; then
      printf 'imported\n'
      return 0
    fi
    printf 'folder\n'
  else
    printf 'folder\n'
  fi
}

qo_source_print() {
  qo_config_load
  local want=${1:-${QO_CFG_EDITION:-auto}}
  local basedir="" actual="" origin=missing where=""
  if basedir=$(qo_pick_basedir "$want"); then
    actual=$(qo_classify_basedir "$basedir")
    origin=$(qo_data_origin "$basedir")
  elif [[ $want == auto || $want == shareware || -z $want ]]; then
    origin=download
  fi
  case $origin in
    steam) where="found in Steam folder" ;;
    gog) where="found in GOG folder" ;;
    heroic) where="found in Heroic folder" ;;
    shareware) where="shareware" ;;
    imported) where="imported folder" ;;
    folder) where="found on disk" ;;
    download) where="will download shareware on launch" ;;
    *) where="no PAKs for this edition" ;;
  esac
  python3 -c 'import json,sys
print(json.dumps({
    "edition": sys.argv[1],
    "basedir": sys.argv[2] or None,
    "origin": sys.argv[3],
    "where": sys.argv[4],
    "want": sys.argv[5],
}))
' "${actual:-}" "${basedir:-}" "$origin" "$where" "$want"
}

qo_pick_basedir() {
  local want=${1:-${QO_CFG_EDITION:-auto}}
  local kind dir
  local rerelease_dir= classic_dir= shareware_dir=

  while IFS=$'\t' read -r kind dir; do
    case $kind in
      rerelease) [[ -z $rerelease_dir ]] && rerelease_dir=$dir ;;
      classic) [[ -z $classic_dir ]] && classic_dir=$dir ;;
      shareware) [[ -z $shareware_dir ]] && shareware_dir=$dir ;;
    esac
  done < <(qo_list_editions)

  case $want in
    rerelease|remaster|remastered)
      [[ -n $rerelease_dir ]] && { printf '%s\n' "$rerelease_dir"; return 0; }
      return 1
      ;;
    classic|original|registered)
      [[ -n $classic_dir ]] && { printf '%s\n' "$classic_dir"; return 0; }
      return 1
      ;;
    shareware)
      [[ -n $shareware_dir ]] && { printf '%s\n' "$shareware_dir"; return 0; }
      return 1
      ;;
    auto|"")
      # Original first so deathmatch is joinable with shareware/classic PAKs.
      # Pick "2021 re-release" explicitly for remaster HUD / extras.
      if [[ -n $classic_dir ]]; then printf '%s\n' "$classic_dir"; return 0; fi
      if [[ -n $shareware_dir ]]; then printf '%s\n' "$shareware_dir"; return 0; fi
      if [[ -n $rerelease_dir ]]; then printf '%s\n' "$rerelease_dir"; return 0; fi
      return 1
      ;;
    *)
      qo_die "unknown edition: $want"
      ;;
  esac
}

qo_maps_for() {
  local edition=$1
  case $edition in
    shareware)
      printf '%s\n' start e1m1 e1m2 e1m3 e1m4 e1m5 e1m6 e1m7 e1m8
      ;;
    classic)
      printf '%s\n' start e1m1 e1m2 e1m3 e1m4 e1m5 e1m6 e1m7 e1m8 \
        e2m1 e2m2 e2m3 e2m4 e2m5 e2m6 e2m7 \
        e3m1 e3m2 e3m3 e3m4 e3m5 e3m6 e3m7 \
        e4m1 e4m2 e4m3 e4m4 e4m5 e4m6 e4m7 e4m8 \
        dm1 dm2 dm3 dm4 dm5 dm6 end
      ;;
    rerelease)
      printf '%s\n' start e1m1 e1m2 e1m3 e1m4 e1m5 e1m6 e1m7 e1m8 \
        e2m1 e2m2 e2m3 e2m4 e2m5 e2m6 e2m7 \
        e3m1 e3m2 e3m3 e3m4 e3m5 e3m6 e3m7 \
        e4m1 e4m2 e4m3 e4m4 e4m5 e4m6 e4m7 e4m8 \
        dm1 dm2 dm3 dm4 dm5 dm6 end
      ;;
    *)
      printf '%s\n' start e1m2
      ;;
  esac
}

qo_running_edition() {
  python3 - "$(qo_status_file)" <<'PY'
import json, os, sys
path = sys.argv[1]
try:
    data = json.load(open(path))
except Exception:
    raise SystemExit(0)
ed = str(data.get("edition") or "")
if data.get("mode") in ("host", "play", "join", "starting") and ed:
    print(ed)
PY
}

qo_map_in_edition() {
  local map=$1 edition=$2
  local maps
  maps=$(qo_maps_print "$edition")
  python3 -c 'import json,sys
want = sys.argv[1].lower()
maps = json.loads(sys.argv[2] or "[]")
raise SystemExit(0 if any(str(m).lower() == want for m in maps) else 1)
' "$map" "$maps"
}

qo_list_maps() {
  local want=${1:-${QO_CFG_EDITION:-auto}}
  local basedir kind
  qo_config_load
  if ! basedir=$(qo_pick_basedir "$want"); then
    qo_maps_for "$want"
    return 0
  fi
  kind=$(qo_classify_basedir "$basedir" || printf '%s' "$want")
  python3 - "$basedir" "$kind" <<'PY'
import json, os, struct, sys, zipfile
root = sys.argv[1]
kind = (sys.argv[2] if len(sys.argv) > 2 else "").lower()
maps = set()

def skip(name):
    n = name.lower()
    return n.startswith("test_") or n.startswith("b_") or n.endswith("old")

def add(name):
    name = name.lower().strip()
    if name and not skip(name):
        maps.add(name)

def from_pak(path):
    try:
        with open(path, "rb") as f:
            if f.read(4) != b"PACK":
                return
            off, size = struct.unpack("<II", f.read(8))
            f.seek(off)
            for _ in range(size // 64):
                raw = f.read(56).split(b"\0", 1)[0].decode("latin1", "replace")
                f.read(8)
                name = raw.replace("\\", "/").lower()
                if name.startswith("maps/") and name.endswith(".bsp"):
                    add(name.rsplit("/", 1)[-1][:-4])
    except OSError:
        return

def from_kpf(path):
    try:
        with zipfile.ZipFile(path) as z:
            for n in z.namelist():
                name = n.replace("\\", "/").lower()
                if name.endswith(".bsp") and "/maps/" in "/" + name:
                    add(name.rsplit("/", 1)[-1][:-4])
    except Exception:
        return

# Engine -basedir only loads id1 unless -game is set. Do not offer
# hipnotic/rogue/rerelease maps for a shareware/classic listen server.
if kind == "rerelease" or os.path.isfile(os.path.join(root, "QuakeEX.kpf")):
    for fn in os.listdir(root):
        low = fn.lower()
        path = os.path.join(root, fn)
        if low.endswith(".kpf"):
            from_kpf(path)
    id1 = None
    for name in ("id1", "Id1", "ID1"):
        p = os.path.join(root, name)
        if os.path.isdir(p):
            id1 = p
            break
    if id1:
        for fn in os.listdir(id1):
            low = fn.lower()
            if low.startswith("pak") and low.endswith(".pak"):
                from_pak(os.path.join(id1, fn))
else:
    id1 = None
    for name in ("id1", "Id1", "ID1"):
        p = os.path.join(root, name)
        if os.path.isdir(p):
            id1 = p
            break
    if id1:
        for fn in os.listdir(id1):
            low = fn.lower()
            if low.startswith("pak") and low.endswith(".pak"):
                from_pak(os.path.join(id1, fn))
            elif low.endswith(".bsp"):
                add(low[:-4])

ordered = sorted(maps, key=lambda n: (
    0 if n.startswith("dm") else 1 if n == "start" else 2 if n[:1] == "e" and "m" in n else 3,
    n,
))
if not ordered:
    sys.exit(1)
print("\n".join(ordered))
PY
}

qo_maps_print() {
  local want=${1:-auto}
  local lines
  if lines=$(qo_list_maps "$want"); then
    python3 -c 'import json,sys; print(json.dumps([ln.strip() for ln in sys.stdin if ln.strip()]))' <<<"$lines"
  else
    python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' $(qo_maps_for "$want")
  fi
}

# --- shareware fetch -------------------------------------------------------

QO_SHAREWARE_URLS=(
  "https://www.gamers.org/pub/idgames2/idstuff/quake/quake106.zip"
  "https://ftp.gwdg.de/pub/misc/ftp.idsoftware.com/idstuff/quake/quake106.zip"
  "https://image.dosgamesarchive.com/games/quake106.zip"
  "https://raw.githubusercontent.com/Jason2Brownlee/QuakeOfficialArchive/main/bin/quake106.zip"
)

qo_lowercase_tree() {
  local root=$1
  local path base dir lower
  # Rename deepest paths first so parents still exist.
  while IFS= read -r path; do
    base=$(basename "$path")
    dir=$(dirname "$path")
    lower=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')
    [[ $base == "$lower" ]] && continue
    if [[ -e $dir/$lower && $path != "$dir/$lower" ]]; then
      continue
    fi
    mv "$path" "$dir/$lower"
  done < <(find "$root" -depth -mindepth 1 -print)
}

qo_extract_archive() {
  local archive=$1 dest=$2
  mkdir -p "$dest"
  if command -v 7z >/dev/null; then
    7z x -y -o"$dest" "$archive" >/dev/null
    return
  fi
  if command -v bsdtar >/dev/null; then
    bsdtar -xf "$archive" -C "$dest"
    return
  fi
  unzip -qo "$archive" -d "$dest"
}

qo_fetch_shareware() {
  qo_mkdirs
  local dest
  dest=$(qo_shareware_dir)
  if qo_has_pak0 "$dest"; then
    qo_log "shareware already present at $dest"
    qo_status_set idle
    return 0
  fi

  local work zip
  work=$(qo_cache_dir)/fetch
  rm -rf "$work"
  mkdir -p "$work"
  zip=$work/quake106.zip

  qo_status_patch fetch downloading 0 "Downloading Quake shareware"

  local url ok=0
  for url in "${QO_SHAREWARE_URLS[@]}"; do
    qo_log "trying $url"
    if curl -L --fail --retry 1 --retry-delay 1 --connect-timeout 8 --max-time 90 --progress-bar -o "$zip" "$url"; then
      ok=1
      break
    fi
    rm -f "$zip"
  done
  (( ok )) || qo_die "could not download Quake shareware"

  qo_status_patch fetch extract 60 "Extracting shareware"
  qo_extract_archive "$zip" "$work/zip"

  local resource
  resource=$(find "$work/zip" -iname 'resource.1' -print -quit)
  if [[ -n $resource ]]; then
    qo_extract_archive "$resource" "$work/id1src"
  else
    mkdir -p "$work/id1src"
    find "$work/zip" -iname 'pak0.pak' -exec cp {} "$work/id1src/" \;
  fi

  qo_lowercase_tree "$work/id1src"

  local pak
  pak=$(find "$work/id1src" -iname 'pak0.pak' -print -quit)
  [[ -n $pak ]] || qo_die "shareware archive did not contain pak0.pak"
  qo_is_pak "$pak" || qo_die "extracted pak0.pak is not a Quake PAK"

  mkdir -p "$dest/id1"
  cp -f "$pak" "$dest/id1/pak0.pak"
  # Keep any accompanying config/maps that came with shareware.
  local extra
  extra=$(dirname "$pak")
  if [[ -d $extra ]]; then
    find "$extra" -maxdepth 1 -type f ! -iname 'pak0.pak' -exec cp -n {} "$dest/id1/" \;
  fi

  rm -rf "$work"
  qo_has_pak0 "$dest" || qo_die "shareware install failed"
  qo_log "shareware installed at $dest"
  qo_status_patch fetch done 100 "Shareware ready"
}

# --- GPU / Wayland ---------------------------------------------------------

qo_hardware_icds() {
  local dir=/usr/share/vulkan/icd.d
  [[ -d $dir ]] || return 0
  find "$dir" -maxdepth 1 -name '*.json' ! -name 'lvp_icd*.json' -print
}

qo_software_icd() {
  local candidate
  for candidate in /usr/share/vulkan/icd.d/lvp_icd.x86_64.json /usr/share/vulkan/icd.d/lvp_icd.json; do
    [[ -f $candidate ]] && { printf '%s\n' "$candidate"; return 0; }
  done
  return 1
}

qo_prepare_gpu() {
  local want=${1:-${QO_CFG_RENDERER:-auto}}
  QO_GPU_KIND=gpu
  unset VK_DRIVER_FILES VK_ICD_FILENAMES || true

  local hw sw
  hw=$(qo_hardware_icds | head -n1 || true)
  sw=$(qo_software_icd || true)

  case $want in
    software|cpu|llvmpipe|lavapipe)
      [[ -n $sw ]] || qo_die "software Vulkan (lavapipe) is not installed — try: omarchy pkg add vulkan-swrast"
      export VK_DRIVER_FILES=$sw
      export VK_ICD_FILENAMES=$sw
      QO_GPU_KIND=software
      qo_log "using software Vulkan ($sw)"
      ;;
    gpu|hardware)
      [[ -n $hw ]] || qo_die "no hardware Vulkan ICD found"
      QO_GPU_KIND=gpu
      ;;
    auto|"")
      if [[ -n $hw ]]; then
        QO_GPU_KIND=gpu
      elif [[ -n $sw ]]; then
        export VK_DRIVER_FILES=$sw
        export VK_ICD_FILENAMES=$sw
        QO_GPU_KIND=software
        qo_log "no GPU Vulkan ICD; falling back to lavapipe"
      else
        qo_die "no Vulkan ICD found (install GPU drivers or vulkan-swrast)"
      fi
      ;;
    *)
      qo_die "unknown renderer: $want"
      ;;
  esac

  if [[ $QO_GPU_KIND == gpu ]] && command -v omarchy-hw-hybrid-gpu >/dev/null && omarchy-hw-hybrid-gpu; then
    export DRI_PRIME="${DRI_PRIME:-1}"
    export __NV_PRIME_RENDER_OFFLOAD="${__NV_PRIME_RENDER_OFFLOAD:-1}"
    export __VK_LAYER_NV_optimus="${__VK_LAYER_NV_optimus:-NVIDIA_only}"
  fi
}

qo_prepare_wayland() {
  if [[ ${XDG_SESSION_TYPE:-} != wayland && -z ${WAYLAND_DISPLAY:-} ]]; then
    qo_die "Quake needs a Wayland session (Hyprland)"
  fi
  export SDL_VIDEODRIVER=wayland
  export SDL_VIDEO_WAYLAND_WMCLASS=$QO_WINDOW_CLASS
  export SDL_APP_ID=$QO_APP_ID
}

# --- engine ----------------------------------------------------------------

qo_find_engine() {
  local candidate
  for candidate in \
    "${QO_ENGINE:-}" \
    "${QO_ROOT:-}/vkquake" \
    "${QO_ROOT:-}/build/engine/vkquake" \
    "${HOME}/.local/lib/omarchy-quake/vkquake" \
    "${HOME}/.local/lib/quake-omarchy/vkquake" \
    /usr/lib/omarchy-quake/vkquake \
    /usr/local/lib/omarchy-quake/vkquake \
    /usr/lib/quake-omarchy/vkquake \
    /usr/local/lib/quake-omarchy/vkquake
  do
    [[ -n $candidate && -x $candidate ]] && { printf '%s\n' "$candidate"; return 0; }
  done
  return 1
}

qo_engine() {
  local engine
  engine=$(qo_find_engine) || qo_die "vkQuake is not built. Run: $QO_ROOT/scripts/install.sh"
  printf '%s\n' "$engine"
}

# --- status ----------------------------------------------------------------

qo_status_starting() {
  local mode=$1 map=${2:-} edition=${3:-}
  qo_mkdirs
  python3 - "$mode" "$map" "$edition" "$(qo_status_file)" <<'PY'
import json, os, sys, time
mode, game_map, edition, path = sys.argv[1:5]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except json.JSONDecodeError:
        data = {}
data.update({
    "version": 1,
    "mode": "starting",
    "launch": mode,
    "running": False,
    "window": False,
    "map": game_map or None,
    "edition": edition or None,
    "error": None,
    "fetch": None,
    "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
})
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f)
    f.write("\n")
os.replace(tmp, path)
PY
}

qo_status_set() {
  local mode=${1:-idle}
  local error=${2:-}
  qo_mkdirs
  python3 - "$mode" "$error" "$(qo_status_file)" <<'PY'
import json, os, sys, time
mode, error, path = sys.argv[1:4]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except json.JSONDecodeError:
        data = {}
data["version"] = 1
data["mode"] = mode
data["error"] = error or None
data["updated_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
if mode in ("idle", "error"):
    data["running"] = False
    data["window"] = False
    if mode == "idle":
        data["pid"] = None
        data["fetch"] = None
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f)
    f.write("\n")
os.replace(tmp, path)
PY
}

qo_status_patch() {
  # qo_status_patch fetch phase percent message
  local kind=$1 phase=${2:-} percent=${3:-0} message=${4:-}
  qo_mkdirs
  python3 - "$kind" "$phase" "$percent" "$message" "$(qo_status_file)" <<'PY'
import json, os, sys, time
kind, phase, percent, message, path = sys.argv[1:6]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except json.JSONDecodeError:
        data = {}
data["version"] = 1
data["updated_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
if kind == "fetch":
    data["mode"] = "fetch"
    data["running"] = False
    data["error"] = None
    data["fetch"] = {"phase": phase, "percent": int(float(percent)), "message": message}
elif kind == "running":
    data["mode"] = phase
    data["running"] = True
    data["pid"] = int(percent)
    data["error"] = None
    data["fetch"] = None
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f)
    f.write("\n")
os.replace(tmp, path)
PY
}

qo_status_merge() {
  python3 - "$(qo_status_file)" <<'PY'
import json, os, sys, time
path = sys.argv[1]
patch = json.load(sys.stdin)
data = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except json.JSONDecodeError:
        data = {}
data.update(patch)
data["version"] = 1
data["updated_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f)
    f.write("\n")
os.replace(tmp, path)
PY
}

qo_status_reap() {
  local file
  file=$(qo_status_file)
  [[ -f $file ]] || return 0
  python3 - "$file" <<'PY'
import json, os, sys
path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except Exception:
    raise SystemExit(0)
pid = data.get("pid")
alive = False
if pid not in (None, "", 0, "0"):
    try:
        os.kill(int(pid), 0)
        alive = True
    except (OSError, ValueError, TypeError):
        alive = False
if data.get("running") and not alive:
    data["running"] = False
    data["alive"] = False
    data["mode"] = "idle"
    data["pid"] = None
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f)
        f.write("\n")
    os.replace(tmp, path)
PY
}

qo_status_print() {
  qo_mkdirs
  qo_status_reap
  local file
  file=$(qo_status_file)
  if [[ -f $file ]]; then
    python3 - "$file" <<'PY'
import json, os, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
data["alive"] = False
pid = data.get("pid")
if pid:
    try:
        os.kill(int(pid), 0)
        data["alive"] = True
    except OSError:
        data["alive"] = False
        data["running"] = False
print(json.dumps(data))
PY
  else
    printf '%s\n' '{"version":1,"mode":"idle","running":false,"pid":null}'
  fi
}

qo_open_panel() {
  command -v omarchy-shell >/dev/null || qo_die "omarchy-shell is not running"
  qo_mkdirs
  qo_status_reap
  local out
  out=$(omarchy-shell shell summon quake.omarchy '{"mode":"main"}' 2>&1) || \
    qo_die "could not open the Quake panel${out:+: $out}"
  if [[ $out == unknown ]]; then
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
    omarchy-shell shell enablePlugin quake.omarchy '{}' >/dev/null 2>&1 || true
    out=$(omarchy-shell shell summon quake.omarchy '{"mode":"main"}' 2>&1) || true
  fi
  [[ $out == ok ]] || qo_die "could not open the Quake panel${out:+: $out}"
}

# --- Tailscale / host discovery --------------------------------------------

qo_tailscale_ip() {
  command -v tailscale >/dev/null || return 1
  tailscale ip -4 2>/dev/null | head -n1
}

qo_tailscale_name() {
  command -v tailscale >/dev/null || return 1
  tailscale status --json 2>/dev/null | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
self = d.get("Self") or {}
print(self.get("HostName") or (self.get("DNSName") or "").split(".")[0])'
}

qo_tailscale_dns() {
  command -v tailscale >/dev/null || return 1
  tailscale status --json 2>/dev/null | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
name = ((d.get("Self") or {}).get("DNSName") or "").rstrip(".")
if not name:
    raise SystemExit(1)
print(name)'
}

qo_tailscale_up() {
  command -v tailscale >/dev/null || return 1
  tailscale status --json 2>/dev/null | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
raise SystemExit(0 if d.get("BackendState") == "Running" else 1)'
}

qo_tailscale_peer_ips() {
  command -v tailscale >/dev/null || return 0
  tailscale status --json 2>/dev/null | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
for peer in (d.get("Peer") or {}).values():
    if not peer or peer.get("Online") is False:
        continue
    ips = peer.get("TailscaleIPs") or []
    v4 = [ip for ip in ips if ":" not in ip]
    if v4:
        print(v4[0])
'
}

qo_host_ips() {
  local ts
  ts=$(qo_tailscale_ip || true)
  [[ -n $ts ]] && printf '%s\n' "$ts"
  hostname -I 2>/dev/null | tr ' ' '\n' | awk 'NF && $0 !~ /^127\./ && $0 !~ /^172\.17\./'
}

qo_join_target_for() {
  local port=${1:-$QO_PORT}
  local dns ip name
  dns=$(qo_tailscale_dns 2>/dev/null || true)
  ip=$(qo_tailscale_ip 2>/dev/null || true)
  name=$(qo_tailscale_name 2>/dev/null || true)
  # Prefer the Tailscale IPv4. MagicDNS names are longer than Quake's
  # in-game join field (22 chars) and the demo loop races +connect.
  if [[ -n $ip ]]; then
    printf '%s:%s\n' "$ip" "$port"
  elif [[ -n $dns ]]; then
    printf '%s:%s\n' "$dns" "$port"
  elif [[ -n $name ]]; then
    printf '%s:%s\n' "$name" "$port"
  else
    ip=$(qo_host_ips | head -n1)
    [[ -n $ip ]] && printf '%s:%s\n' "$ip" "$port"
  fi
}

qo_write_session_files() {
  local mode=$1 map=${2:-} connect=${3:-}
  local dir name
  dir=$(qo_userdir)/id1
  mkdir -p "$dir"
  name=$(qo_sanitize_player_name "${QO_CFG_NAME:-$(qo_default_player_name)}")

  cat >"$dir/quake.rc" <<'RC'
// managed by quake-omarchy — skips startdemos so host/join can actually run
exec default.cfg
exec config.cfg
exec autoexec.cfg
stuffcmds
exec omarchy-session.cfg
RC

  # Do not run `name` / `color` here. Those stringcmds during listen-server
  # signon make the client parse svc_updatecolors before maxclients is set
  # (Host_Error: svc_updatecolors > MAX_SCOREBOARD). Identity is cvars in
  # omarchy.cfg; the engine sends them at CL_SignonReply.
  case $mode in
    host)
      cat >"$dir/omarchy-session.cfg" <<CFG
cl_startdemos "0"
stopdemo
deathmatch "1"
coop "0"
hostname "$name"
map $map
CFG
      ;;
    join)
      cat >"$dir/omarchy-session.cfg" <<CFG
cl_startdemos "0"
stopdemo
connect $connect
CFG
      ;;
    *)
      cat >"$dir/omarchy-session.cfg" <<'CFG'
cl_startdemos "1"
startdemos demo1 demo2 demo3
CFG
      ;;
  esac
}

# The 2021 re-release keeps real loc strings in id1/pak0.pak. vkQuake loads
# localization/loc_english.txt from disk or QuakeEX.kpf first — and the kpf
# copy is a 1-line placeholder, which is why centerprints show $MAP_*.
qo_extract_localization() {
  local basedir=$1
  local dest
  dest=$(qo_userdir)/localization/loc_english.txt
  [[ -f $dest && $(wc -c <"$dest") -gt 1000 ]] && return 0
  python3 - "$basedir" "$dest" <<'PY'
import os, struct, sys
basedir, dest = sys.argv[1], sys.argv[2]
os.makedirs(os.path.dirname(dest), exist_ok=True)
wanted = "localization/loc_english.txt"

def from_pak(pak):
    try:
        with open(pak, "rb") as f:
            if f.read(4) != b"PACK":
                return None
            off, size = struct.unpack("<II", f.read(8))
            f.seek(off)
            n = size // 64
            entries = []
            for _ in range(n):
                name = f.read(56).split(b"\0", 1)[0].decode("latin1", "replace")
                o, s = struct.unpack("<II", f.read(8))
                entries.append((name, o, s))
            for name, o, s in entries:
                if name.replace("\\", "/").lower() == wanted:
                    f.seek(o)
                    data = f.read(s)
                    if b"=" in data and len(data) > 1000:
                        return data
    except OSError:
        return None
    return None

candidates = []
for gamedir in ("id1", "Id1", "ID1"):
    folder = os.path.join(basedir, gamedir)
    if not os.path.isdir(folder):
        continue
    for fn in os.listdir(folder):
        if fn.lower() == "pak0.pak":
            candidates.append(os.path.join(folder, fn))
data = None
for pak in candidates:
    data = from_pak(pak)
    if data:
        break
if not data:
    raise SystemExit(0)
with open(dest, "wb") as out:
    out.write(data)
PY
}

qo_game_window_mapped() {
  hyprctl clients -j 2>/dev/null | python3 -c 'import json,sys
try:
    clients = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
want = {"org.omarchy.quake", "vkquake"}
for c in clients:
    cls = str(c.get("class") or "")
    initial = str(c.get("initialClass") or "")
    title = str(c.get("title") or "")
    if cls not in want and initial not in want and title != "Quake":
        continue
    size = c.get("size") or [0, 0]
    w = size[0] if isinstance(size, list) and size else 0
    mapped = c.get("mapped", True)
    hidden = c.get("hidden", False)
    if mapped and not hidden and w >= 320:
        raise SystemExit(0)
raise SystemExit(1)
'
}

qo_join_command_for() {
  local target
  target=$(qo_join_target_for "${1:-$QO_PORT}")
  [[ -n $target ]] || return 1
  printf 'quake-omarchy join %s\n' "$target"
}

qo_clipboard_text() {
  wl-paste -n 2>/dev/null || true
}

qo_join_from_clipboard() {
  local clip
  clip=$(qo_clipboard_text)
  [[ -n $clip ]] || return 1
  python3 -c '
import re, sys
raw = sys.argv[1].strip()
low = raw.lower()
if "quake-omarchy join" in low:
    raw = raw[low.index("quake-omarchy join") + len("quake-omarchy join"):].strip().split()[0]
elif re.match(r"^\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?$", raw):
    pass
elif re.match(r"^[\w.-]+:\d+$", raw):
    pass
else:
    raise SystemExit(1)
if ":" not in raw:
    raw = raw + ":26000"
print(raw)
' "$clip"
}

qo_parse_join() {
  python3 -c 'import sys
raw = " ".join(sys.argv[1:]).strip()
for prefix in (
    "quake-omarchy join ",
    "quake-omarchy join",
    "quake-omarchy://join/",
    "quake-omarchy://",
    "quake://",
):
    if raw.lower().startswith(prefix):
        raw = raw[len(prefix):].strip()
        break
parts = raw.split()
raw = parts[-1] if parts else ""
raw = raw.strip().strip("/")
if not raw:
    raise SystemExit(1)
if raw.count(":") == 0:
    raw = raw + ":26000"
print(raw)
' "$@"
}

qo_copy_text() {
  local text=$1
  if qo_cmd omarchy-clipboard-paste-text; then
    omarchy-clipboard-paste-text --copy-only "$text" >/dev/null 2>&1 && return 0
  fi
  if qo_cmd wl-copy; then
    printf '%s' "$text" | wl-copy && return 0
  fi
  return 1
}

qo_share_join() {
  local cmd via
  qo_config_load
  if [[ -n ${1:-} ]]; then
    cmd=$1
  else
    cmd=$(python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
host=d.get("host") or {}
print(host.get("command") or "")
' <"$(qo_status_file)" 2>/dev/null || true)
    [[ -n $cmd ]] || cmd=$(qo_join_command_for "$QO_CFG_PORT")
  fi
  [[ -n $cmd ]] || qo_die "nothing to share — host a game first"
  if qo_copy_text "$cmd"; then
    qo_log "copied: $cmd"
    qo_osd "$cmd"
    qo_notify "Join command copied" "$cmd"
  else
    qo_log "$cmd"
  fi
  printf '%s\n' "$cmd"
}

qo_advertise_host() {
  local map=$1 port=$2 mode=$3 edition=$4
  local ip name dns target via
  ip=$(qo_tailscale_ip || true)
  dns=$(qo_tailscale_dns || true)
  name=$(qo_tailscale_name || hostname)
  if [[ -n $dns || -n $ip ]] && qo_tailscale_up; then
    via=tailscale
  else
    via=lan
    [[ -n $ip ]] || ip=$(qo_host_ips | head -n1)
  fi
  target=$(qo_join_target_for "$port")
  python3 - <<PY
import json
print(json.dumps({
  "name": "$name",
  "ip": "$ip",
  "dns": "$dns",
  "join": "$target",
  "command": "quake-omarchy join $target",
  "via": "$via",
  "port": int("$port"),
  "beacon_port": int("$QO_BEACON_PORT"),
  "map": "$map",
  "mode": "$mode",
  "edition": "$edition",
  "app": "quake-omarchy",
}))
PY
}

qo_beacon_py() {
  printf '%s\n' "${QO_BEACON:-$QO_ROOT/lib/beacon.py}"
}

qo_self_ips() {
  local ip
  ip=$(qo_tailscale_ip 2>/dev/null || true)
  [[ -n $ip ]] && printf '%s\n' "$ip"
  printf '%s\n' 127.0.0.1
  hostname -I 2>/dev/null | tr ' ' '\n' | awk 'NF && $0 !~ /^127\./'
}

qo_beacon_stop() {
  pkill -f 'lib/beacon.py serve' 2>/dev/null || true
  rm -f "$(qo_state_dir)/beacon.pid"
}

qo_scan_peers() {
  local ips lan self_args=() ip
  ips=$(qo_tailscale_peer_ips || true)
  lan=$(qo_host_ips || true)
  while IFS= read -r ip || [[ -n ${ip:-} ]]; do
    [[ -n ${ip:-} ]] && self_args+=(--exclude "$ip")
  done < <(qo_self_ips || true)
  python3 "$(qo_beacon_py)" ping --port "$QO_BEACON_PORT" --timeout 1.2 \
    ${self_args[@]+"${self_args[@]}"} \
    255.255.255.255 $ips $lan 2>/dev/null || printf '[]\n'
}

# --- session wrap ----------------------------------------------------------

qo_cmd() { command -v "$1" >/dev/null; }

qo_session_begin() {
  qo_mkdirs
  local idle_stay dnd night profile
  idle_stay=false
  dnd=off
  night=false
  profile=$(powerprofilesctl get 2>/dev/null || printf '')

  if qo_cmd omarchy-shell; then
    idle_stay=$(omarchy-shell idle status 2>/dev/null | python3 -c 'import json,sys
try:
    print("true" if json.load(sys.stdin).get("stayAwake") else "false")
except Exception:
    print("false")')
    dnd=$(omarchy-shell notifications dndState 2>/dev/null || printf 'off')
  fi
  if qo_cmd omarchy-toggle-nightlight; then
    night=$(omarchy-toggle-nightlight --status 2>/dev/null | python3 -c 'import json,sys
try:
    print("true" if json.load(sys.stdin).get("enabled") else "false")
except Exception:
    print("false")')
  fi

  {
    printf 'IDLE_STAY=%s\n' "$idle_stay"
    printf 'DND=%s\n' "$dnd"
    printf 'NIGHT=%s\n' "$night"
    printf 'PROFILE=%s\n' "$profile"
  } | qo_atomic_write "$(qo_session_file)"

  if qo_cmd omarchy-shell; then
    [[ $idle_stay == false ]] && omarchy-shell idle disable >/dev/null 2>&1 || true
    [[ $dnd == off ]] && omarchy-shell notifications setDnd on >/dev/null 2>&1 || true
  fi
  if [[ $night == true ]] && qo_cmd omarchy-toggle-nightlight; then
    omarchy-toggle-nightlight >/dev/null 2>&1 || true
  fi
  if [[ -n $profile ]] && qo_cmd powerprofilesctl; then
    powerprofilesctl set performance >/dev/null 2>&1 || true
  fi
}

qo_session_end() {
  local file
  file=$(qo_session_file)
  [[ -f $file ]] || return 0
  # shellcheck disable=SC1090
  source "$file"
  if qo_cmd omarchy-shell; then
    if [[ ${IDLE_STAY:-false} == false ]]; then
      omarchy-shell idle enable >/dev/null 2>&1 || true
    fi
    if [[ ${DND:-off} == off ]]; then
      omarchy-shell notifications setDnd off >/dev/null 2>&1 || true
    fi
  fi
  if [[ ${NIGHT:-false} == true ]] && qo_cmd omarchy-toggle-nightlight; then
    local now
    now=$(omarchy-toggle-nightlight --status 2>/dev/null | python3 -c 'import json,sys
try:
    print("true" if json.load(sys.stdin).get("enabled") else "false")
except Exception:
    print("false")')
    [[ $now == false ]] && omarchy-toggle-nightlight >/dev/null 2>&1 || true
  fi
  if [[ -n ${PROFILE:-} ]] && qo_cmd powerprofilesctl; then
    powerprofilesctl set "$PROFILE" >/dev/null 2>&1 || true
  fi
  rm -f "$file"
}

qo_watch_lock() {
  local pid=$1
  qo_cmd omarchy-hyprland-session-locked || return 0
  local stopped=0
  while kill -0 "$pid" 2>/dev/null; do
    if omarchy-hyprland-session-locked; then
      if (( stopped == 0 )); then
        kill -STOP "$pid" 2>/dev/null || true
        stopped=1
      fi
    elif (( stopped == 1 )); then
      kill -CONT "$pid" 2>/dev/null || true
      stopped=0
    fi
    sleep 0.7
  done
}

# --- launch ----------------------------------------------------------------

qo_game_pid() {
  local file pid
  file=$(qo_pid_file)
  [[ -f $file ]] || return 1
  pid=$(<"$file")
  if [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null; then
    printf '%s\n' "$pid"
    return 0
  fi
  rm -f "$file"
  qo_status_reap
  return 1
}

qo_focus() {
  if qo_cmd omarchy-launch-or-focus; then
    omarchy-launch-or-focus "$QO_WINDOW_CLASS" "true"
    return 0
  fi
  if qo_cmd hyprctl; then
    hyprctl dispatch "hl.dsp.focus({ window = \"class:$QO_WINDOW_CLASS\" })" >/dev/null 2>&1 || \
      hyprctl dispatch focuswindow "class:$QO_WINDOW_CLASS" >/dev/null 2>&1 || true
  fi
}

qo_stop() {
  local pid i
  if pid=$(qo_game_pid); then
    kill -TERM "$pid" 2>/dev/null || true
    for i in $(seq 1 30); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  fi
  qo_beacon_stop
  rm -f "$(qo_pid_file)"
  qo_session_end
  qo_status_set idle
}

qo_ensure_data() {
  local edition=${1:-auto}
  local basedir
  if basedir=$(qo_pick_basedir "$edition"); then
    printf '%s\n' "$basedir"
    return 0
  fi
  if [[ $edition == auto || $edition == shareware ]]; then
    qo_notify "Downloading shareware" "First run — fetching pak0.pak"
    qo_fetch_shareware
    if basedir=$(qo_pick_basedir shareware); then
      printf '%s\n' "$basedir"
      return 0
    fi
    qo_die "shareware download finished but pak0.pak is missing"
  fi
  qo_die "no $edition data found. Import a Quake folder: quake-omarchy import /path/to/Quake"
}

qo_notify() {
  local title=$1 body=${2:-}
  if qo_cmd omarchy-notification-send; then
    omarchy-notification-send -g "Q" --app-name "Quake" "$title" "$body" || true
  elif qo_cmd notify-send; then
    notify-send "Quake" "$body"
  fi
}

qo_osd() {
  local msg=$1
  qo_cmd omarchy-osd && omarchy-osd -m "$msg" -d 2500 >/dev/null 2>&1 || true
}

qo_launch() {
  local mode=$1
  shift

  qo_config_load
  local edition=$QO_CFG_EDITION
  local windowed=$QO_CFG_WINDOWED
  local map=$QO_CFG_MAP
  local port=$QO_CFG_PORT
  local players=$QO_CFG_PLAYERS
  local connect_host=
  local deathmatch=1
  local extra=()

  while (($#)); do
    case $1 in
      --edition) edition=$2; shift 2 ;;
      --windowed) windowed=true; shift ;;
      --fullscreen) windowed=false; shift ;;
      --map) map=$2; shift 2 ;;
      --port) port=$2; shift 2 ;;
      --players) players=$2; shift 2 ;;
      --connect) connect_host=$2; shift 2 ;;
      --coop) deathmatch=0; shift ;;
      --deathmatch) deathmatch=1; shift ;;
      --name) QO_CFG_NAME=$(qo_sanitize_player_name "$2"); shift 2 ;;
      --shirt|--topcolor) QO_CFG_SHIRT=$(qo_clamp_color "$2"); shift 2 ;;
      --pants|--bottomcolor) QO_CFG_PANTS=$(qo_clamp_color "$2"); shift 2 ;;
      --) shift; extra+=("$@"); break ;;
      *) extra+=("$1"); shift ;;
    esac
  done

  if pid=$(qo_game_pid); then
    qo_log "already running (pid $pid)"
    qo_focus
    return 0
  fi

  qo_mkdirs
  qo_status_starting "$mode" "${map:-}" "$edition"
  if [[ -z ${QO_FROM_PANEL:-} ]] && command -v omarchy-shell >/dev/null; then
    omarchy-shell shell summon quake.omarchy '{"mode":"starting"}' >/dev/null 2>&1 || true
  fi

  local basedir engine
  basedir=$(qo_ensure_data "$edition")
  basedir=$(qo_casefold_basedir "$basedir")
  local actual
  actual=$(qo_classify_basedir "$basedir")
  [[ -n $actual ]] || actual=$(qo_classify_basedir "$(qo_ensure_data "$edition")")
  QO_ACTIVE_EDITION=$actual
  export QO_ACTIVE_EDITION
  QO_CFG_EDITION=$edition
  [[ -n $map ]] && QO_CFG_MAP=$map
  qo_extract_localization "$basedir"
  engine=$(qo_engine)

  qo_prepare_wayland
  qo_prepare_gpu "$QO_CFG_RENDERER"

  mkdir -p "$(qo_userdir)/id1"
  qo_mkdirs
  qo_sanitize_vkquake_cfg "$(qo_userdir)/id1/vkQuake.cfg"
  qo_config_save
  qo_write_video_cfg

  local args=(
    -basedir "$basedir"
    -userdir "$(qo_userdir)"
    +rcon_password "$QO_CFG_RCON"
  )
  local fs=$QO_CFG_FULLSCREEN
  [[ $QO_CFG_WINDOWED == true || $windowed == true ]] && fs=false
  local w=$QO_CFG_WIDTH h=$QO_CFG_HEIGHT
  if [[ -z $w || $w == 0 || -z $h || $h == 0 ]]; then
    local native
    native=$(qo_native_res)
    if [[ $native == *x* ]]; then
      w=${native%x*}
      h=${native#*x}
    fi
  fi
  if [[ $fs == true ]]; then
    args+=(-fullscreen)
  else
    args+=(-window)
  fi
  # Native/desktop fullscreen: do not pass -width/-height. Forcing 4K on the
  # CLI plus r_rtshadows makes vkQuake spend 10–20s in VID/Vulkan init.
  if [[ ${QO_CFG_WIDTH:-0} != 0 && ${QO_CFG_HEIGHT:-0} != 0 && -n $w && -n $h ]]; then
    args+=(-width "$w" -height "$h")
  fi

  case $mode in
    host)
      [[ -z $map ]] && map=$QO_DEFAULT_MAP
      args+=(-listen "$players" -port "$port")
      qo_write_session_files host "$map"
      ;;
    join)
      [[ -n $connect_host ]] || qo_die "join requires host[:port]"
      connect_host=$(qo_parse_join "$connect_host")
      args+=(-port "$port")
      qo_write_session_files join "" "$connect_host"
      ;;
    play)
      qo_write_session_files play
      if [[ -n $map ]]; then
        printf 'map %s\n' "$map" >>"$(qo_userdir)/id1/omarchy-session.cfg"
      fi
      ;;
    *)
      qo_die "unknown launch mode: $mode"
      ;;
  esac
  args+=("${extra[@]+"${extra[@]}"}")

  trap 'qo_stop' INT TERM

  qo_log "engine=$engine basedir=$basedir edition=$actual mode=$mode"
  "$engine" "${args[@]}" &
  local pid=$!
  printf '%s\n' "$pid" >"$(qo_pid_file)"

  python3 - "$pid" "$mode" "$actual" "$basedir" "$map" "$windowed" "$QO_GPU_KIND" "$connect_host" "$(qo_status_file)" <<'PY'
import json, os, sys, time
pid, mode, edition, basedir, game_map, windowed, renderer, connect_host, path = sys.argv[1:10]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except json.JSONDecodeError:
        data = {}
data.update({
    "version": 1,
    "mode": mode,
    "launch": mode,
    "running": True,
    "window": bool(data.get("window")),
    "pid": int(pid),
    "edition": edition,
    "basedir": basedir,
    "map": game_map,
    "windowed": windowed == "true",
    "renderer": renderer,
    "join": connect_host if mode == "join" else None,
    "fetch": None,
    "error": None,
    "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
})
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f)
    f.write("\n")
os.replace(tmp, path)
PY

  (
    local i
    for i in $(seq 1 120); do
      if qo_game_window_mapped; then
        printf '%s\n' '{"window":true}' | qo_status_merge
        break
      fi
      sleep 0.15
    done
  ) &

  qo_session_begin
  qo_watch_lock "$pid" &

  local beacon_pid=
  if [[ $mode == host ]]; then
    qo_beacon_stop
    (
      local host_json join_cmd via
      host_json=$(qo_advertise_host "$map" "$port" "$( ((deathmatch)) && echo deathmatch || echo coop)" "$actual")
      python3 "$(qo_beacon_py)" serve --port "$QO_BEACON_PORT" --payload "$host_json" &
      printf '%s\n' $! >"$(qo_state_dir)/beacon.pid"
      printf '%s' "$host_json" | python3 - "$(qo_status_file)" <<'PY'
import json, sys
path = sys.argv[1]
host = json.load(sys.stdin)
data = {}
try:
    with open(path) as f:
        data = json.load(f)
except Exception:
    data = {}
data["host"] = host
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f)
    f.write("\n")
os = __import__("os")
os.replace(tmp, path)
PY
      join_cmd=$(printf '%s' "$host_json" | python3 -c 'import json,sys; print((json.load(sys.stdin) or {}).get("command") or "")')
      via=$(printf '%s' "$host_json" | python3 -c 'import json,sys; print((json.load(sys.stdin) or {}).get("via") or "")')
      if [[ -n $join_cmd ]]; then
        qo_copy_text "$join_cmd" || true
        if [[ $via == tailscale ]]; then
          qo_osd "Copied $join_cmd"
          qo_notify "Deathmatch ready — send this" "$join_cmd"$'\n'"During the match: Super+Shift+Q changes maps."
        else
          qo_osd "Copied $join_cmd (LAN only)"
          qo_notify "Deathmatch ready on LAN" "$join_cmd"
        fi
      fi
      wait
    ) &
  fi

  wait "$pid"
  local rc=$?
  trap - INT TERM
  if [[ -f $(qo_state_dir)/beacon.pid ]]; then
    kill "$(cat "$(qo_state_dir)/beacon.pid")" 2>/dev/null || true
    rm -f "$(qo_state_dir)/beacon.pid"
  fi
  rm -f "$(qo_pid_file)"
  qo_session_end
  qo_status_set idle
  return $rc
}

qo_import() {
  local dir=$1
  [[ -d $dir ]] || qo_die "not a directory: $dir"
  local kind
  kind=$(qo_classify_basedir "$dir") || qo_die "no Quake PAK/kpf data in $dir"
  qo_config_set basedir "$(readlink -f "$dir")"
  qo_config_set edition "$kind"
  qo_log "using $kind data at $dir"
}

qo_editions_report() {
  qo_config_load
  python3 - <<PY
import json, subprocess, os
lib = os.environ.get("QO_LIB")
out = subprocess.check_output(["bash", "-c", "source \"\$1\"; qo_config_load; qo_list_editions", "bash", lib], text=True)
items = []
for line in out.splitlines():
    kind, _, path = line.partition("\t")
    if path:
        items.append({"edition": kind, "path": path})
print(json.dumps({"configured": "${QO_CFG_EDITION}", "available": items}))
PY
}
