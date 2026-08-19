Patches on stock vkQuake 1.35. `scripts/build-engine.sh` applies each
`*.patch` after clone (and skips ones already applied).

`0001-wayland-idle-quit-and-quattro-title.patch`

- Wait for the in-flight present / destroy the swapchain before
  `SDL_DestroyWindow`. Without this, NVIDIA's Wayland WSI can SIGSEGV
  in `wl_proxy_marshal_flags` from `GL_EndRenderingTask` on quit.
- Window title / SDL app metadata: Quake. Console `version`
  is still vkQuake.

`0002-register-rcon-password.patch`

- Register the `rcon_password` cvar in `Datagram_Init`. Stock 1.35
  defines it but never registers it, so `rcon_password "..."` in a
  cfg is `unknown command rcon_password`.

`0003-rcon-defer-changelevel.patch`

- Queue `changelevel` / `map` / `restart` from rcon onto `Cbuf` instead
  of running them inside `Datagram_GetAnyMessage`. Listen-server
  `Loop_SendMessage` SIGSEGVs if sockets are rebuilt mid-packet.

`0004-loopback-null-guards.patch`

- Return -1 from loopback send/recv if the socket or its peer is
  disconnected, instead of SIGSEGV when an overlay steals focus from
  a listen-server client.
