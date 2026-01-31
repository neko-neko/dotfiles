local wezterm = require 'wezterm'
local mux = wezterm.mux
local act = wezterm.action

-- toggle full-screeen on startup
wezterm.on("gui-startup", function()
  local tab, pane, window = mux.spawn_window(cmd or {})
  window:gui_window():toggle_fullscreen()
end)

---------------------------------------------------------------
-- Workspace Management
---------------------------------------------------------------
local function workspace_switcher(window, pane)
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
end

local function create_workspace(window, pane, line)
  if line then
    window:perform_action(
      act.SwitchToWorkspace {
        name = line,
      },
      pane
    )
  end
end

local function rename_workspace(window, pane, line)
  if line then
    wezterm.mux.rename_workspace(
      wezterm.mux.get_active_workspace(),
      line
    )
  end
end

local config = wezterm.config_builder()
config.check_for_updates = true
config.use_ime = true
config.audible_bell = 'SystemBeep'

-- window
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}
config.native_macos_fullscreen_mode = true
config.tab_bar_at_bottom = true

-- colors
config.color_scheme = 'nordfox'

-- keys
config.keys = {
  { key = 'LeftArrow',  mods = 'SUPER', action = act.ActivateTabRelative(-1) },
  { key = 'RightArrow', mods = 'SUPER', action = act.ActivateTabRelative(1) },
  { key = 'Enter', mods = 'SHIFT', action = wezterm.action.SendString('\n') },
  { key = 't', mods = 'SUPER', action = act.SpawnTab 'CurrentPaneDomain' },

  -- Switch to workspace
  {
    mods = 'SUPER',
    key = 's',
    action = wezterm.action_callback(workspace_switcher),
  },

  -- Create new workspace
  {
    mods = 'SUPER|SHIFT',
    key = 'n',
    action = act.PromptInputLine {
      description = "(wezterm) Create new workspace:",
      action = wezterm.action_callback(create_workspace),
    },
  },

  -- Rename workspace
  {
    mods = 'SUPER|SHIFT',
    key = 'r',
    action = act.PromptInputLine {
      description = '(wezterm) Rename workspace:',
      action = wezterm.action_callback(rename_workspace),
    },
  },
}

return config
