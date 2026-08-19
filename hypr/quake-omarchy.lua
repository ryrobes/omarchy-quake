-- Quake. Do not force fullscreen or confine the pointer: those
-- fight windowed mode and make it impossible to give the mouse back to
-- Hyprland. The engine handles fullscreen; Esc opens the menu and
-- releases the cursor when the window is not fullscreen.
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
--
-- Super+Shift+Q is compositor-level, so it still fires while vkQuake has
-- the mouse grab. During a hosted match it is the map/score overlay;
-- otherwise it is the launcher. Super+Shift+[ / ] cycle maps with no UI.

o.bind("SUPER + SHIFT + Q", "Quake", "omarchy-shell shell toggle quake.omarchy")
o.bind("SUPER + SHIFT + code:35", "Quake next map", "omarchy-quake next-map")
o.bind("SUPER + SHIFT + code:34", "Quake previous map", "omarchy-quake prev-map")

o.window("org.omarchy.quake", {
  tag = "-default-opacity",
  opacity = "1 1",
  idle_inhibit = "focus",
  content = "game",
  immediate = true,
  no_anim = true,
  rounding = 0,
})

o.window("vkquake", {
  tag = "-default-opacity",
  opacity = "1 1",
  idle_inhibit = "focus",
  content = "game",
  immediate = true,
  no_anim = true,
  rounding = 0,
})
