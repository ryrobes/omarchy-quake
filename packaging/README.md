# Packaging omarchy-quake

This tree is the source for the **omarchy-quake** Arch package. The Omarchy ISO does not ship the game. Users install it on demand from **Install > Gaming > Quake**, which runs `omarchy-pkg-add omarchy-quake`.

That helper is `sudo pacman -S`, so the package has to live in the `[omarchy]` extra repo ([omacom-io/omarchy-pkgs](https://github.com/omacom-io/omarchy-pkgs)), not only on the public AUR. AUR `vkquake` is the wrong package: it is unpatched upstream and has no launcher or plugin.

## What the package installs

| Path | Role |
|---|---|
| `/usr/bin/omarchy-quake` | CLI |
| `/usr/lib/omarchy-quake/` | `vkquake` + `lib/*.sh` + Python helpers |
| `/usr/share/omarchy-quake/plugin/` | Quickshell plugin files (copy, no symlinks) |
| `/usr/share/applications/org.omarchy.quake.desktop` | Apps launcher (`Exec=omarchy-quake panel`) |
| `/usr/share/omarchy-quake/hypr/quake.lua` | Window rules + Super+Shift+Q (for the Omarchy PR or user copy) |

`package()` must not write `$HOME`. Plugin discovery only looks at `~/.config/omarchy/plugins/<id>/`, so the Omarchy installer copies the plugin and enables it after pacman.

## Test on a fresh Omarchy 4 VM

A QEMU VM with a stock Omarchy 4 ISO is the right rehearsal: extra is empty, so you prove `makepkg` + `pacman -U` + the installer commands, then play.

Log into the **graphical** session (plugin enable needs `omarchy-shell`), then:

```bash
git clone https://github.com/ryrobes/omarchy-quake.git
cd omarchy-quake
./scripts/test-packaged-install.sh
```

That script prints every command before it runs: unit tests, DESTDIR layout, `makepkg` of *this* checkout, `pacman -U` (stand-in for `omarchy-pkg-add omarchy-quake`), copy/enable the plugin, then `gtk-launch org.omarchy.quake`. Pass `--no-launch` to stop before the panel. VMs without a GPU get `vulkan-swrast`. First Play downloads shareware (~18MB).

## Build locally

From a tagged checkout:

```bash
# layout check, no compiler
make test

# full /usr tree into a destroot
make PREFIX=/usr DESTDIR=/tmp/omarchy-quake-root install
```

Or `makepkg -s` from a copy of `packaging/PKGBUILD` next to a release tarball. The first `sha256sums` entry is the GitHub archive for the matching release tag.

vkQuake 1.35.0 is a second source tarball so the package build does not git-clone during `makepkg`.

## omarchy-pkgs drop-in

Copy into `omarchy-pkgs`:

```
pkgbuilds/omarchy-quake/PKGBUILD          <- this PKGBUILD
pkgbuilds/omarchy-quake/.omarchy/package.json  <- packaging/package.json
```

```bash
bin/add-package omarchy-quake --local
# then replace the scaffold with these files
bin/repo release --package omarchy-quake
```

Leave it off the `fast` ring until it has been used on edge.

## Omarchy runtime PR (separate repo)

`basecamp/omarchy` only gets the menu stub and the user-side installer. Drafts:

- `omarchy-install-gaming-quake.example.sh`
- `omarchy-remove-gaming-quake.example.sh`
- `omarchy-menu.snippet.jsonc`

Notes for that PR:

- Stock Omarchy 4 `hyprland.lua` does not load `~/.config/hypr/apps/*.lua`, so
  the installer copies `quake.lua` there *and* adds
  `require("hypr.apps.quake-omarchy")` to `~/.config/hypr/hyprland.lua`. If the
  maintainers would rather not edit that file, the window rules can ship as
  `default/hypr/apps/quake.lua` (auto-loaded like `steam.lua`) instead.
- The shell picks up a new plugin dir asynchronously; the installer rescans and
  retries `omarchy-plugin-enable` instead of calling it once.
- Menu rows gate on `when: omarchy-pkg-present`, like the other Gaming rows.

Do not merge that PR until `pacman -S omarchy-quake` works on a stock Omarchy box.
