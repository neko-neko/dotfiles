local wezterm = require 'wezterm'
local mux = wezterm.mux
local act = wezterm.action

-- toggle full-screeen on startup
wezterm.on("gui-startup", function()
  local tab, pane, window = mux.spawn_window(cmd or {})
  window:gui_window():toggle_fullscreen()
end)

local config = {
  check_for_updates = true,
  use_ime = true,
  -- window
  window_padding = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0,
  },
  native_macos_fullscreen_mode = true,
  tab_bar_at_bottom = true,
  -- colors
  color_scheme = 'nordfox',
  font = wezterm.font_with_fallback({
    "Hack Nerd Font",
    "JetBrains Mono",
  }),
  -- keys
  keys = {
    { key = 'LeftArrow',  mods = 'SUPER', action = act.ActivateTabRelative(-1) },
    { key = 'RightArrow', mods = 'SUPER', action = act.ActivateTabRelative(1) },
    { key = 't', mods = 'SUPER', action = act.SpawnTab 'CurrentPaneDomain' },
  },
}
return config
