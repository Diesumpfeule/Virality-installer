#!/usr/bin/env bash
# Installs the Virality mod (MaxWasUnavailable) for Content Warning on Linux (Fedora etc.)
# Content Warning runs via Steam Play (Proton). Needs: bash, python3 (both preinstalled on Fedora).
#
# Usage:  bash install-virality-linux.sh [--uninstall] [--game-path "/path/to/Content Warning"]
set -euo pipefail

GAME_PATH=""
UNINSTALL=0
while [ $# -gt 0 ]; do
    case "$1" in
        --uninstall) UNINSTALL=1 ;;
        --game-path) GAME_PATH="${2:?missing path}"; shift ;;
        -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

command -v python3 >/dev/null || { echo "python3 not found. Install it: sudo dnf install python3" >&2; exit 1; }

find_game() {
    local roots=(
        "$HOME/.local/share/Steam"
        "$HOME/.steam/steam"
        "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
    )
    local libs=() root vdf line
    for root in "${roots[@]}"; do
        [ -d "$root/steamapps" ] || continue
        libs+=("$root")
        vdf="$root/steamapps/libraryfolders.vdf"
        if [ -f "$vdf" ]; then
            while IFS= read -r line; do libs+=("$line"); done < <(sed -n 's/.*"path"[[:space:]]*"\([^"]*\)".*/\1/p' "$vdf")
        fi
    done
    for root in "${libs[@]}"; do
        if [ -f "$root/steamapps/common/Content Warning/Content Warning.exe" ]; then
            printf '%s\n' "$root/steamapps/common/Content Warning"
            return 0
        fi
    done
    return 1
}

if [ -z "$GAME_PATH" ]; then
    GAME_PATH="$(find_game || true)"
fi
if [ -z "$GAME_PATH" ] || [ ! -f "$GAME_PATH/Content Warning.exe" ]; then
    echo "Content Warning not found. Install it in Steam first, or use --game-path \"<folder>\"." >&2
    exit 1
fi
echo "Game folder: $GAME_PATH"

if pgrep -f "[C]ontent Warning\.exe" >/dev/null 2>&1; then
    echo "Content Warning is running. Close it and run the script again." >&2
    exit 1
fi

python3 -I - "$GAME_PATH" "$UNINSTALL" <<'PY'
import json, os, shutil, sys, tempfile, urllib.request, zipfile

game, uninstall = sys.argv[1], sys.argv[2] == "1"
ROOT = ("MaxWasUnavailable", "Virality")
API = "https://thunderstore.io/api/experimental/package"
DL = "https://thunderstore.io/package/download"
plugins = os.path.join(game, "BepInEx", "plugins")
mod_dir = os.path.join(plugins, f"{ROOT[0]}-{ROOT[1]}")

if uninstall:
    if os.path.isdir(mod_dir):
        shutil.rmtree(mod_dir)
        print("Virality removed.")
    else:
        print("Virality is not installed.")
    sys.exit(0)

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "virality-installer"})
    return urllib.request.urlopen(req, timeout=60)

seen = set()
tmp = tempfile.mkdtemp(prefix="cw-virality-")

def install(ns, name, version=None):
    pid = f"{ns}-{name}"
    if pid in seen:
        return
    seen.add(pid)
    meta = None
    try:
        url = f"{API}/{ns}/{name}/{version}/" if version else f"{API}/{ns}/{name}/"
        info = json.load(get(url))
        meta = info.get("latest", info)
    except Exception as e:
        if not version:
            sys.exit(f"Package {pid} not found on Thunderstore: {e}")
        print(f"Warning: no metadata for {pid}-{version}, its dependencies are skipped.")
    if not version:
        version = meta["version_number"]
    print(f"Installing {pid} {version}")
    zpath = os.path.join(tmp, f"{pid}-{version}.zip")
    with get(f"{DL}/{ns}/{name}/{version}/") as r, open(zpath, "wb") as f:
        shutil.copyfileobj(r, f)
    out = os.path.join(tmp, f"{pid}-{version}")
    with zipfile.ZipFile(zpath) as z:
        z.extractall(out)
    if name.startswith("BepInExPack"):
        packs = [d for d in os.listdir(out) if d.startswith("BepInExPack") and os.path.isdir(os.path.join(out, d))]
        src = os.path.join(out, packs[0]) if packs else out
        shutil.copytree(src, game, dirs_exist_ok=True)
    else:
        shutil.copytree(out, os.path.join(plugins, pid), dirs_exist_ok=True)
    for dep in (meta or {}).get("dependencies", []):
        p = dep.split("-")
        if len(p) != 3:
            print(f"Warning: skipping unparsable dependency: {dep}")
            continue
        install(*p)

try:
    os.makedirs(plugins, exist_ok=True)
    install(*ROOT)
finally:
    shutil.rmtree(tmp, ignore_errors=True)
PY

cat <<'EOF'

Files installed. ONE manual step is still needed (Proton needs it to load BepInEx):
  Steam > right-click Content Warning > Properties > Launch Options, paste:

  WINEDLLOVERRIDES="winhttp=n,b" %command%

Then start the game once. Settings: in-game under Settings > Mods > Virality.
All players in the lobby need the mod.
EOF
