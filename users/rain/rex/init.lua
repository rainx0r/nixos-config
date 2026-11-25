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

-- Project and worktree switchers (tmux prefix g / prefix e).
local terminal = "com.superlogical.terminal"
local shell_flavor = "com.superlogical.terminal.shell"
local home = os.getenv("HOME") or ""

-- The server's PATH can be bare (/usr/bin:/bin on macOS), so look for git and
-- friends in the Nix profiles too.
local exec_env = {
	PATH = table.concat({
		home .. "/.nix-profile/bin",
		"/etc/profiles/per-user/" .. (os.getenv("USER") or "") .. "/bin",
		"/run/current-system/sw/bin",
		"/nix/var/nix/profiles/default/bin",
		os.getenv("PATH") or "/usr/bin:/bin",
	}, ":"),
}

local function run(argv, cwd)
	return rex.exec(argv, { cwd = cwd, env = exec_env, stderr = false })
end

local function tilde(path)
	return home ~= "" and path:sub(1, #home) == home and "~" .. path:sub(#home + 1) or path
end

local function pick(prompt)
	local id, why, detail = rex.ui.pick(prompt)
	if id == nil and why ~= "cancelled" then
		rex.log("warn", prompt.title .. ": " .. tostring(why) .. (detail and (" " .. detail) or ""))
	end
	return id
end

-- prefix g: projects ----------------------------------------------------------

local project_roots = {
	{ dir = home .. "/Repositories/github.com", depth = "2" },
	{ dir = home .. "/Experiments", depth = "1" },
}

local function session_ids_by_label()
	local by_label = {}
	local list = rex.call("session.list")
	for _, s in ipairs((list and list.sessions) or {}) do
		by_label[s.label] = by_label[s.label] or s.session_id
	end
	return by_label
end

local function project_items(open)
	local items = {}
	for _, root in ipairs(project_roots) do
		local r = run({ "find", root.dir, "-mindepth", root.depth, "-maxdepth", root.depth, "-type", "d" })
		for path in ((r and r.stdout) or ""):gmatch("[^\n]+") do
			local name = path:match("[^/]+$")
			items[#items + 1] = {
				id = path,
				-- owner/repo for GitHub checkouts, the folder name for experiments.
				title = path:sub(#root.dir + 2),
				subtitle = tilde(path),
				icon = "folder",
				detail = open[name] and "open" or nil,
			}
		end
	end
	table.sort(items, function(a, b)
		return a.title < b.title
	end)
	return items
end

rex.action({
	name = "sessionizer",
	title = "Go to Project…",
	run = function(ctx)
		local open = session_ids_by_label()
		local dir = pick({
			title = "Go to project",
			placeholder = "Filter projects",
			items = project_items(open),
		})
		if dir == nil then
			return
		end

		local name = dir:match("[^/]+$")
		local session = open[name]
		if not session then
			local created, err = rex.call("session.create", {
				label = name,
				initial_windows = {
					{ layout = rex.layout.block({ flavor = shell_flavor, options = { cwd = dir } }) },
				},
			})
			if not created then
				rex.log("warn", "sessionizer: couldn't create " .. name .. ": " .. tostring(err))
				return
			end
			session = created.session_id
		end
		rex.client.queue("session.select", { session_id = session })
	end,
})
rex.bind("cmd+g", "sessionizer")

-- prefix e: worktrees ---------------------------------------------------------

-- Working directory of the focused pane's foreground program (the shell, or
-- e.g. nvim), like tmux's pane_current_path. Rex's own `pwd` needs the shell
-- to report its directory, which this zsh setup doesn't.
local function focused_cwd(ctx)
	local p = ctx.block_id and rex.block.call(terminal, "process", { block_id = ctx.block_id })
	return p and ((p.foreground and p.foreground.cwd) or (p.child and p.child.cwd)) or nil
end

-- `git worktree list --porcelain`, without bare entries, as { path, branch }.
local function list_worktrees(cwd)
	local r = cwd and run({ "git", "worktree", "list", "--porcelain" }, cwd)
	if not (r and r.ok) then
		return nil
	end
	local worktrees, current = {}, nil
	for line in (r.stdout .. "\n"):gmatch("([^\n]*)\n") do
		local path = line:match("^worktree (.+)")
		if path then
			current = { path = path, branch = "" }
		elseif current and line:match("^branch ") then
			current.branch = line:gsub("^branch refs/heads/", ""):gsub("^branch ", "")
		elseif current and line == "detached" then
			current.branch = "(detached)"
		elseif current and line == "bare" then
			current.bare = true
		elseif current and line == "" then
			if not current.bare then
				worktrees[#worktrees + 1] = current
			end
			current = nil
		end
	end
	return worktrees
end

-- "New worktree…": the last row of the worktree picker.
local new_worktree_id = ":new-worktree" -- can't clash with a path
local worktrees_root = home .. "/.worktrees"

-- Ask for a branch, then add its worktree at ~/.worktrees/<project>/<branch>.
-- Offers local and remote branches without a worktree yet; typing a name that
-- isn't listed creates that branch from HEAD. Returns the new worktree's path.
local function add_worktree(cwd, worktrees)
	local used = {}
	for _, wt in ipairs(worktrees) do
		used[wt.branch] = true
	end

	local items, seen, remote_branch, local_branch = {}, {}, {}, {}
	local heads = run({ "git", "for-each-ref", "--format=%(refname:short)", "refs/heads" }, cwd)
	for b in ((heads and heads.stdout) or ""):gmatch("[^\n]+") do
		local_branch[b] = true
		if not used[b] and not seen[b] then
			seen[b] = true
			items[#items + 1] = { id = b, icon = "branch" }
		end
	end
	local remotes = run({ "git", "for-each-ref", "--format=%(refname:short)", "refs/remotes" }, cwd)
	for ref in ((remotes and remotes.stdout) or ""):gmatch("[^\n]+") do
		local name = ref:match("^[^/]+/(.+)$")
		if name and name ~= "HEAD" and not used[name] and not seen[name] then
			seen[name] = true
			remote_branch[ref] = name
			items[#items + 1] = { id = ref, title = name, subtitle = ref, icon = "globe" }
		end
	end

	local answer = pick({
		title = "New worktree",
		placeholder = "Branch, or a new branch name",
		confirm = "Add worktree",
		allow_other = true,
		items = items,
	})
	if answer == nil then
		return nil
	end

	-- argv after `git worktree add`, given the path.
	local branch, args
	if type(answer) == "table" then
		branch = answer.text:match("^%s*(.-)%s*$")
		if branch == "" then
			return nil, "cancelled"
		end
		if local_branch[branch] then
			args = function(path)
				return { path, branch }
			end -- typed an existing branch
		else
			args = function(path)
				return { "-b", branch, path }
			end
		end
	elseif remote_branch[answer] then
		-- remote/branch: create a local branch tracking it.
		branch = remote_branch[answer]
		args = function(path)
			return { "--track", "-b", branch, path, answer }
		end
	else
		branch = answer
		args = function(path)
			return { path, branch }
		end
	end

	-- The main worktree comes first, and names the project.
	local project = worktrees[1].path:match("[^/]+$")
	local path = worktrees_root .. "/" .. project .. "/" .. branch:gsub("/", "-")
	local argv = { "git", "worktree", "add" }
	for _, a in ipairs(args(path)) do
		argv[#argv + 1] = a
	end
	local r = rex.exec(argv, { cwd = cwd, env = exec_env })
	if not (r and r.ok) then
		return nil, "failed", ((r and r.stderr) or ""):gsub("%s+$", "")
	end
	return path
end

rex.action({
	name = "worktrees",
	title = "Go to Worktree…",
	run = function(ctx)
		local cwd = focused_cwd(ctx)
		local worktrees = list_worktrees(cwd)
		if not worktrees then
			rex.log("warn", "worktrees: not in a git repository (" .. tostring(cwd) .. ")")
			return
		end

		-- Worktrees of one repo are siblings with distinct names, so a tab labelled
		-- with the folder name is that worktree's tab.
		local tabs = {}
		for _, w in ipairs((rex.session.view({}) or {}).windows or {}) do
			tabs[w.label] = w.window_id
		end

		local items = {}
		for _, wt in ipairs(worktrees or {}) do
			items[#items + 1] = {
				id = wt.path,
				title = wt.branch,
				subtitle = tilde(wt.path),
				icon = "branch",
				detail = tabs[wt.path:match("[^/]+$")] and "open" or nil,
			}
		end

		items[#items + 1] = { id = new_worktree_id, title = "New worktree…", icon = "plus" }

		local dir = pick({
			title = "Go to worktree",
			placeholder = "Filter worktrees",
			items = items,
		})
		if dir == nil then
			return
		end

		if dir == new_worktree_id then
			local why, detail
			dir, why, detail = add_worktree(cwd, worktrees)
			if dir == nil then
				if why == "failed" then
					-- Show git's complaint (its last line, e.g. "fatal: ...") in the palette.
					rex.ui.pick({
						title = "Couldn't add worktree",
						confirm = "OK",
						items = { { id = "ok", title = (detail or "unknown error"):match("([^\n]*)$") } },
					})
				end
				return
			end
		end

		local label = dir:match("[^/]+$")
		local window = tabs[label]
		if not window then
			local created, err = rex.session.new_window({
				window_label = label,
				layout = rex.layout.block({ flavor = shell_flavor, options = { cwd = dir } }),
			})
			if not created then
				rex.log("warn", "worktrees: couldn't open " .. label .. ": " .. tostring(err))
				return
			end
			window = created.window_id
		end
		-- Making the tab active on the server doesn't move the app, so ask it to.
		rex.client.queue("session.select", { session_id = ctx.session_id, window_id = window })
	end,
})
rex.bind("cmd+e", "worktrees")

-- Navigation
-- ctrl+h/j/k/l: move pane focus, unless the focused pane runs a program that
-- does its own split navigation; then pass the key through to it. nvim (the
-- rex plugin in rainx0r/nvim) hands focus back with `rex focus` at its edges.
local passthrough = { nvim = true, vim = true, tmux = true }

local function wants_key(ctx)
	-- Function bindings may not get ctx.block_id; without it, Rex uses the
	-- current block.
	local p = rex.block.call(terminal, "process", ctx.block_id and { block_id = ctx.block_id } or {})
	local fg = p and p.foreground
	return fg ~= nil and (passthrough[fg.name] or passthrough[(fg.argv0 or ""):match("[^/]*$")]) == true
end

for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
	rex.bind("ctrl+" .. key, function(ctx)
		if wants_key(ctx) then
			return false
		end -- Rex sends the key to the terminal
		-- session.focus_direction stops at layout edges by default; pass wrap = true to wrap.
		local _, err = rex.session.focus_direction({ direction = direction })
		if err then
			rex.log("warn", "focus " .. direction .. " failed: " .. tostring(err))
		end
		return true
	end)
end
