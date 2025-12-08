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

    -- Switch to workspace
    {
      mods = 'SUPER',
      key = 's',
      action = wezterm.action_callback(function(window, pane)
        local workspaces = {}
        for i, name in ipairs(wezterm.mux.get_workspace_names()) do
          table.insert(workspaces, {
            id = name,
            label = string.format("%d. %s", i, name),
          })
        end
        local current = wezterm.mux.get_active_workspace()
        window:perform_action(act.InputSelector {
          action = wezterm.action_callback(function (_, _, id, label)
            if not id and not label then
              wezterm.log_info "Workspace selection canceled"
            else
              window:perform_action(act.SwitchToWorkspace { name = id }, pane)
            end
          end),
          title = "Select workspace",
          choices = workspaces,
          fuzzy = true,
        }, pane)
      end),
    },

    -- Create new workspace
    {
      mods = 'SUPER|SHIFT',
      key = 'n',
      action = act.PromptInputLine {
        description = "(wezterm) Create new workspace:",
        action = wezterm.action_callback(function(window, pane, line)
          if line then
            window:perform_action(
              act.SwitchToWorkspace {
                name = line,
              },
              pane
            )
          end
        end),
      },
    },

    -- Rename workspace
    {
      mods = 'SUPER|SHIFT',
      key = 'r',
      action = act.PromptInputLine {
        description = '(wezterm) Rename workspace:',
        action = wezterm.action_callback(function(window, pane, line)
          if line then
            wezterm.mux.rename_workspace(
              wezterm.mux.get_active_workspace(),
              line
            )
          end
        end),
      },
    },
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
