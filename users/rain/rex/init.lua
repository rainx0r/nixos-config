-- Panes
rex.bind("cmd+x", "pane.close")
rex.bind("cmd+z", "pane.zoom")

-- Sessions
rex.bind("cmd+s", "session.switch")

local config_dir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/rex"

-- Run a command in a floating pane over the current tab; it closes when the
-- command exits. Stand-in for tmux's display-popup / fzf --tmux.
local function popup(command)
  local _, err = rex.session.new_layer{
    bounds = { 0.1, 0.1, 0.8, 0.8 },
    focus = true,
    layout = rex.layout.block{
      flavor = "com.superlogical.terminal.shell",
      options = { command = command },
    },
  }
  if err then rex.log("popup failed: " .. tostring(err)) end
  return true
end

-- prefix g: project switcher
rex.bind("cmd+g", function(ctx)
  return popup({ "zsh", config_dir .. "/sessionizer.zsh", ctx.client_id })
end)

-- Navigation
-- TODO: pass these through to nvim once smart-splits' Rex backend is set up.
rex.bind("ctrl+h", "pane.focus.left")
rex.bind("ctrl+j", "pane.focus.down")
rex.bind("ctrl+k", "pane.focus.up")
rex.bind("ctrl+l", "pane.focus.right")
-- rex.bind("ctrl+q", "client.tab.previous")
-- rex.bind("ctrl+w", "client.tab.next")
