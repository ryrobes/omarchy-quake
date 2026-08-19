vkQuake is cloned here on `make install` (`vendor/vkQuake`). That tree is gitignored — this repo does not vendor the engine.

This is still vkQuake 1.35 (GPLv2), not a renamed engine. Quake is
the Omarchy launcher/plugin around it. `scripts/build-engine.sh` applies
`patches/vkquake/*.patch` after clone: wait for the GPU before destroying
the Wayland window on quit, and set the window title to Quake.

Do not copy `build/` from another machine — Meson stores absolute paths
and ninja will try to rebuild against the original host.
