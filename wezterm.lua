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

  -- keys
  keys = {
    { key = 'LeftArrow',  mods = 'SUPER', action = act.ActivateTabRelative(-1) },
    { key = 'RightArrow', mods = 'SUPER', action = act.ActivateTabRelative(1) },
    { key = 't', mods = 'SUPER', action = act.SpawnTab 'CurrentPaneDomain' },
  },

  -- font
  font = wezterm.font_with_fallback({
    family='Monaspace Neon',
    harfbuzz_features={ 'calt', 'liga', 'dlig', 'ss01', 'ss02', 'ss03', 'ss04', 'ss05', 'ss06', 'ss07', 'ss08' },
    stretch='UltraCondensed',
  }),

  font_rules = {
    { -- Italic
      intensity = 'Normal',
      italic = true,
      font = wezterm.font({
        -- family="Monaspace Radon",  -- script style
        family='Monaspace Xenon', -- courier-like
        style = 'Italic',
      })
    },
    { -- Bold
      intensity = 'Bold',
      italic = false,
      font = wezterm.font({
        family='Monaspace Krypton',
        family='Monaspace Krypton',
        -- weight='ExtraBold',
        weight='Bold',
      })
    },
    { -- Bold Italic
      intensity = 'Bold',
      italic = true,
      font = wezterm.font({
        family='Monaspace Xenon',
        style='Italic',
        weight='Bold',
      })
    },
  },
}
return config
