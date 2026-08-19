# Packaging omarchy-quake

This tree is the source for the **omarchy-quake** Arch package. The Omarchy ISO does not ship the game. Users install it on demand from **Install > Gaming > Quake**, which runs `omarchy-pkg-add omarchy-quake`.

That helper is `sudo pacman -S`, so the package has to live in the `[omarchy]` extra repo ([omacom-io/omarchy-pkgs](https://github.com/omacom-io/omarchy-pkgs)), not only on the public AUR. AUR `vkquake` is the wrong package: it is unpatched upstream and has no launcher or plugin.

## What the package installs

| Path | Role |
|---|---|
| `/usr/bin/quake-omarchy` | CLI (`omarchy-quake` is a symlink) |
| `/usr/lib/omarchy-quake/` | `vkquake` + `lib/*.sh` + Python helpers |
| `/usr/share/omarchy-quake/plugin/` | Quickshell plugin files (copy, no symlinks) |
| `/usr/share/applications/org.omarchy.quake.desktop` | Apps launcher (`Exec=quake-omarchy panel`) |
| `/usr/share/omarchy-quake/hypr/quake.lua` | Window rules + Super+Shift+Q (for the Omarchy PR or user copy) |

`package()` must not write `$HOME`. Plugin discovery only looks at `~/.config/omarchy/plugins/<id>/`, so the Omarchy installer copies the plugin and enables it after pacman.

## Build locally

From a tagged checkout (after `v1.5.0` exists):

```bash
# layout check, no compiler
make test

# full /usr tree into a destroot
make PREFIX=/usr DESTDIR=/tmp/omarchy-quake-root install
```

Or `makepkg -s` from a copy of `packaging/PKGBUILD` next to a release tarball. Fill the first `sha256sums` entry after the GitHub archive for `v$pkgver` exists (`SKIP` is a placeholder).

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

Do not merge that PR until `pacman -S omarchy-quake` works on a stock Omarchy box.
