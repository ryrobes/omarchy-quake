# omarchy-quake

Quake 1 on [Omarchy](https://omarchy.org/) 4: native Wayland via vkQuake 1.35 + SDL3, Hyprland window rules, shareware fetched on first run, and deathmatch over Tailscale or LAN.

Source: [github.com/ryrobes/omarchy-quake](https://github.com/ryrobes/omarchy-quake). Package and launcher are both **omarchy-quake**.

The product is **Quake**. The renderer is still **vkQuake 1.35** (GPLv2). The window title says Quake; the console `version` command still reports vkQuake. The binary we compile stays `vkquake`.

The in-game tilde console stays in the game. Omarchy's Super+` pulldown owns the desktop. A unix-socket bridge into QML is left for a later use case.

## What v1 does

- Compiles **vkQuake 1.35** (Vulkan, SDL3, native Wayland)
- **GPU or not**: hardware Vulkan when present, lavapipe (`vulkan-swrast`) otherwise
- **PAK sources**: official shareware download, original `id1/pak0+pak1`, or the 2021 re-release (`QuakeEX.kpf` / `rerelease/`)
- Discovers Steam / GOG-style folders, or `omarchy-quake import /path/to/quake`
- Hyprland: exclusive fullscreen, no dimming, tearing allowed, idle inhibit, pointer confine
- Session wrap: stay-awake, DND, night light off, performance profile, pause on lock
- **Deathmatch**: `omarchy-quake host` copies a join command; `join` uses the clipboard, then LAN/Tailscale
- Omarchy plugin panel (Play / Host / Join / edition picker) + `.desktop`

## Install (development)

```bash
# packages (skip any already installed)
omarchy pkg add \
  base-devel git meson ninja pkgconf \
  sdl3 vulkan-headers vulkan-icd-loader glslang spirv-tools \
  mpg123 libvorbis flac opus libogg

make install
```

That clones vkQuake 1.35 into `vendor/vkQuake` if missing, compiles it, and installs the launcher to `~/.local`, the Quickshell plugin, and Hyprland rules. The engine is not in git. Do **not** copy a `build/` directory from another machine — Meson bakes in absolute paths. First Play downloads shareware.

If `make install` still mentions a path from another machine, delete `build/` and run it again.

Packaged install (for omarchy-pkgs / `pacman -S omarchy-quake`) uses `DESTDIR` + `PREFIX=/usr` and does not write `$HOME`. See `packaging/README.md`. The Omarchy menu stub is a separate PR against `basecamp/omarchy`; this repo does not inject a Games menu.

```bash
omarchy-quake                  # play
omarchy-quake host --map e1m2  # copies `omarchy-quake join host:26000`
omarchy-quake join             # paste that command, or scan the tailnet
omarchy-quake share            # copy the join command again
omarchy-quake import ~/Games/Quake
omarchy-quake panel            # Omarchy overlay
```

Hosting copies a one-liner (Tailscale MagicDNS when you're on a tailnet, otherwise a LAN IP). Send it to the other machine; they run it as-is. Both sides need the same PAK set (shareware is enough).

Edition and renderer:

```bash
omarchy-quake config edition auto        # auto|shareware|classic|rerelease
omarchy-quake config renderer auto       # auto|gpu|software
```

## Layout

| Path | Role |
|---|---|
| `bin/omarchy-quake` | CLI |
| `lib/quake-omarchy.sh` | PAK discovery, fetch, GPU, session, launch |
| `lib/beacon.py` | Tailscale host beacon (UDP 26001) |
| `plugin/` | Omarchy shell plugin (`quake.omarchy`) |
| `hypr/quake-omarchy.lua` | Window rules |
| `vendor/vkQuake` | Engine source, cloned on build (gitignored) |
| `patches/vkquake` | Re-applied on each engine build |
| `packaging/` | PKGBUILD and Omarchy installer drafts |

User data lives under XDG: config in `~/.config/quake-omarchy`, shareware/saves in `~/.local/share/quake-omarchy`, live status in `~/.local/state/quake-omarchy/status.json` (the QML hook).

## Panel artwork

The panel uses an original geometric icon and a procedural seismograph backdrop.
The package does not contain Quake logos, screenshots, gameplay footage, or game
data. First Play downloads the original shareware archive, verifies its pinned
SHA-256, and keeps `SLICNSE.TXT` alongside the extracted shareware data.
