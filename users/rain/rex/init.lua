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

-- Resolve the script path in the pane's shell, so it's right on whichever host
-- the popup runs. Pass the ID of the app that pressed the key; it's only valid
-- on the server that ran this Lua, and the script checks and falls back if not.
local function popup_cmd(script, ctx)
  local id = ctx.client_id or ""
  return {
    "sh", "-c", 'exec zsh "${XDG_CONFIG_HOME:-$HOME/.config}/rex/' .. script .. '" ' .. "'" .. id .. "'",
  }
end

-- Run a command in a floating pane over the tab the key was pressed in; it
-- closes when the command exits. Stand-in for tmux's display-popup / fzf --tmux.
-- If that tab already has a picker open, close it instead, so the keys toggle
-- rather than stacking pickers.
local picker_label = "picker"

local function popup(ctx, command, cwd)
  -- The pressed-in tab, not the session's active tab: another app attached to
  -- the session may have switched the active tab since.
  local view = rex.session.view{} or {}
  local window
  for _, w in ipairs(view.windows or {}) do
    for _, layer in ipairs(w.layers or {}) do
      for _, b in ipairs(layer.blocks or {}) do
        if b.block_id == ctx.block_id then window = w end
      end
    end
  end

  if window then
    for _, layer in ipairs(window.layers or {}) do
      for _, b in ipairs(layer.blocks or {}) do
        if layer.kind ~= "tiled" and b.label == picker_label then
          rex.session.close_layer{ layer_id = layer.layer_id }
          return true
        end
      end
    end
  end

  local _, err = rex.session.new_layer{
    window_id = window and window.window_id or nil,
    bounds = { 0.1, 0.1, 0.8, 0.8 },
    focus = true,
    layout = {
      block = {
        flavor = "com.superlogical.terminal.shell",
        label = picker_label,
        options = { command = command, cwd = cwd },
      },
    },
  }
  if err then rex.log("popup failed: " .. tostring(err)) end
  return true
end

-- Working directory of the focused pane's foreground program (the shell, or
-- e.g. nvim), like tmux's pane_current_path. Rex's own `pwd` needs the shell
-- to report its directory, which this zsh setup doesn't.
local function focused_cwd(ctx)
  local p = ctx.block_id
    and rex.block.call("com.superlogical.terminal", "process", { block_id = ctx.block_id })
  return p and ((p.foreground and p.foreground.cwd) or (p.child and p.child.cwd)) or nil
end

-- prefix e: open a worktree of the focused pane's repo as a tab.
-- An action, not a function binding: only actions get ctx.client_id, which the
-- script needs to switch the app that pressed the key.
rex.action{
  name = "worktrees",
  title = "Go to Worktree…",
  run = function(ctx)
    popup(ctx, popup_cmd("worktrees.zsh", ctx), focused_cwd(ctx))
  end,
}
rex.bind("cmd+e", "worktrees")

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
      return popup(ctx, popup_cmd("sessionizer.zsh", ctx))
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
-- ctrl+h/j/k/l: move pane focus, unless the focused pane runs a program that
-- does its own split navigation; then pass the key through to it. nvim (the
-- rex plugin in rainx0r/nvim) hands focus back with `rex focus` at its edges.
local passthrough = { nvim = true, vim = true, tmux = true }

local function wants_key(ctx)
  -- Function bindings may not get ctx.block_id; without it, Rex uses the
  -- current block.
  local p = rex.block.call(
    "com.superlogical.terminal", "process",
    ctx.block_id and { block_id = ctx.block_id } or {}
  )
  local fg = p and p.foreground
  return fg ~= nil and (passthrough[fg.name] or passthrough[(fg.argv0 or ""):match("[^/]*$")]) == true
end

for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  rex.bind("ctrl+" .. key, function(ctx)
    if wants_key(ctx) then return false end -- Rex sends the key to the terminal
    local _, err = rex.session.focus_direction{ direction = direction }
    if err then rex.log("focus " .. direction .. " failed: " .. tostring(err)) end
    return true
  end)
end
-- rex.bind("ctrl+q", "client.tab.previous")
-- rex.bind("ctrl+w", "client.tab.next")
