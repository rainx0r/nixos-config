-- Splits
rex.bind("cmd+shift+h", "pane.split", { direction = "left" })
rex.bind("cmd+shift+j", "pane.split", { direction = "down" })
rex.bind("cmd+shift+k", "pane.split", { direction = "up" })
rex.bind("cmd+shift+l", "pane.split", { direction = "right" })

-- Panes
rex.bind("cmd+x", "pane.close")
rex.bind("cmd+z", "pane.zoom")

-- Sessions
rex.bind("cmd+s", "session.switch")

-- This Lua runs on the local machine even when the focused session lives on a
-- remote host, so resolve the script path in the pane's shell, on that host.
local sessionizer_cmd = {
  "sh", "-c", 'exec zsh "${XDG_CONFIG_HOME:-$HOME/.config}/rex/sessionizer.zsh"',
}

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

-- prefix g: project switcher (fzf in a floating pane), kept to compare
rex.bind("cmd+shift+g", function()
  return popup(sessionizer_cmd)
end)

-- Native project switcher using Rex's own picker (rex.ui.pick).
local home = os.getenv("HOME")
local shell_flavor = "com.superlogical.terminal.shell"
local project_roots = {
  { dir = home .. "/Repositories/github.com", depth = "2", prefix = "github/" },
  { dir = home .. "/Experiments", depth = "1", prefix = "experiments/" },
}

-- TEMP: rex.ui.pick is undocumented; dump what it returns while we figure it out.
local debug_log = (os.getenv("TMPDIR") or "/tmp/") .. "rex-sessionizer.log"
local function debug(label, value)
  local f = io.open(debug_log, "a")
  if not f then return end
  f:write(os.date("%H:%M:%S "), label, ": ", rex.json.encode(value) or tostring(value), "\n")
  f:close()
end

local function list_projects()
  local items = {}
  for _, root in ipairs(project_roots) do
    local r = rex.exec(
      { "find", root.dir, "-mindepth", root.depth, "-maxdepth", root.depth, "-type", "d" },
      { stderr = false }
    )
    for path in ((r and r.stdout) or ""):gmatch("[^\n]+") do
      items[#items + 1] = { id = path, title = root.prefix .. path:sub(#root.dir + 2) }
    end
  end
  table.sort(items, function(a, b) return a.title < b.title end)
  return items
end

local function project_session(label, dir)
  local list = rex.call("session.list")
  for _, s in ipairs((list and list.sessions) or {}) do
    if s.label == label then return s.session_id end
  end
  local created, err = rex.call("session.create", {
    label = label,
    initial_windows = {
      { layout = rex.layout.block{ flavor = shell_flavor, options = { cwd = dir } } },
    },
  })
  if not created then return nil, err end
  return created.session_id
end

rex.action{
  name = "sessionizer",
  title = "Go to Project…",
  run = function(ctx)
    -- rex.ui isn't in every build yet (missing on preview 0.1.0 (1996)).
    if not (rex.ui and rex.ui.pick) then
      return popup(sessionizer_cmd)
    end

    local items = list_projects()
    local picked, err = rex.ui.pick{ title = "Go to project", items = items }
    debug("pick", { picked = picked, err = err })
    if type(picked) == "table" then picked = picked.ids and picked.ids[1] or picked[1] end
    if type(picked) ~= "string" then return end

    local label = picked:match("([^/]+)$")
    local session, serr = project_session(label, picked)
    debug("session", { session = session, err = serr })
    if session then rex.client.queue("session.select", { session_id = session }) end
  end,
}
rex.bind("cmd+g", "sessionizer")

-- Navigation
-- TODO: pass these through to nvim once smart-splits' Rex backend is set up.
rex.bind("ctrl+h", "pane.focus.left")
rex.bind("ctrl+j", "pane.focus.down")
rex.bind("ctrl+k", "pane.focus.up")
rex.bind("ctrl+l", "pane.focus.right")
-- rex.bind("ctrl+q", "client.tab.previous")
-- rex.bind("ctrl+w", "client.tab.next")
