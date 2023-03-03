local wezterm = require 'wezterm'
local mux = wezterm.mux

-- toggle full-screeen on startup
wezterm.on("gui-startup", function()
  local tab, pane, window = mux.spawn_window(cmd or {})
  window:gui_window():toggle_fullscreen()
end)

return {
  check_for_updates = false,
  use_ime = true,
  native_macos_fullscreen_mode = true,

  window_padding = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0,
  },

  color_scheme = 'nordfox',
  font = wezterm.font_with_fallback({
    "JetBrains Mono",
    "Noto Color Emoji",
    "Symbols Nerd Font Mono",
  }),
}
