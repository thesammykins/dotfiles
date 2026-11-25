local HOME  = os.getenv("HOME")
local SHELL = "com.superlogical.terminal.shell"

-- File manager pane in a split beside the focused terminal: fresh on Cmd-B,
-- yazi on Cmd-Shift-B. Swap the two bind lines to change the default.
-- See files/launch.sh for what each does with the terminal it came from.
local function files_action(name, title, manager)
  rex.action{
    name  = name,
    title = title,
    run   = function(ctx)
      local _, err = rex.session.new_split{
        direction = "horizontal",
        side      = "after",
        layout    = rex.layout.block{
          flavor  = SHELL,
          options = {
            command = { HOME .. "/.config/rex/files/launch.sh", ctx.block_id, manager },
          },
        },
      }
      if err ~= nil then error(err, 0) end
    end,
  }
end

files_action("files_fresh", "Open Files in Fresh", "fresh")
files_action("files_yazi", "Pick a File with Yazi", "yazi")

rex.bind("cmd+b", "files_fresh")
rex.bind("cmd+shift+b", "files_yazi")

-- Saved commands. A floating pane runs workflows/pick.sh, which types the
-- chosen command into this terminal. The list is workflows/commands.txt.
rex.action{
  name     = "workflows",
  title    = "Saved Commands…",
  keywords = "workflow snippet command library",
  run      = function(ctx)
    local _, err = rex.session.new_layer{
      bounds = { 0.15, 0.12, 0.7, 0.6 },
      focus  = true,
      layout = rex.layout.block{
        flavor  = SHELL,
        label   = "Saved Commands",
        options = {
          shell   = "none",
          command = { HOME .. "/.config/rex/workflows/pick.sh", ctx.block_id },
        },
      },
    }
    if err ~= nil then error(err, 0) end
  end,
}

rex.bind("ctrl+shift+r", "workflows")

-- Agents in a pane. Pick Claude Code, Codex or OpenCode (or type any other
-- command) and it opens in a split beside the focused pane, in that pane's
-- folder. The command is typed into a shell, so the agent gets the full zsh
-- environment and the pane keeps a shell after the agent exits.

local function focused_dir(ctx)
  if ctx.block_id == nil then return nil end
  local res, err = rex.call("block.method", {
    session_id = ctx.session_id, block_id = ctx.block_id, method = "pwd",
  })
  if err ~= nil or res == nil or res.pwd == nil then return nil end
  local path = res.pwd:gsub("^file://[^/]*", "")
  return (path:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function split_beside(ctx, label, command, ratio)
  local _, err = rex.session.new_split{
    direction = "horizontal",
    side      = "after",
    ratio     = ratio,
    focus     = true,
    layout    = rex.layout.block{
      flavor  = SHELL,
      label   = label,
      options = { cwd = focused_dir(ctx), initial_input = command .. "\n" },
    },
  }
  if err ~= nil then error(err, 0) end
end

local AGENTS = {
  { id = "claude",   title = "Claude Code", icon = "person" },
  { id = "codex",    title = "Codex",       icon = "code" },
  { id = "opencode", title = "OpenCode",    icon = "terminal" },
}

rex.action{
  name     = "agent",
  title    = "Open Agent…",
  keywords = "ai agent claude codex opencode warp",
  args     = { agent = "string?" },
  run      = function(ctx, args)
    local cmd = args.agent
    if cmd == nil then
      local pick = rex.ui.pick{
        title = "Open agent", placeholder = "Agent, or type a command",
        items = AGENTS, allow_other = true,
      }
      if pick == nil then return end
      cmd = type(pick) == "table" and pick.text or pick
    end
    split_beside(ctx, cmd:match("^%S+"), cmd, 0.45)
  end,
}

rex.bind("shift+cmd+a", "agent")

-- Markdown beside the focused pane: mddog lists the folder's .md files.
rex.action{
  name     = "markdown",
  title    = "Preview Markdown",
  keywords = "md mddog readme preview",
  args     = { file = "string?" },
  run      = function(ctx, args)
    split_beside(ctx, "markdown", args.file and ("mdd " .. args.file) or "mdd", 0.5)
  end,
}

rex.bind("shift+cmd+m", "markdown")

-- A real browser in a split (terminal-browser draws pages with kitty
-- graphics). Asks for a URL, or a file or localhost port.
rex.action{
  name     = "browser",
  title    = "Open Browser…",
  keywords = "web url browse terminal-browser localhost",
  args     = { url = "string?" },
  run      = function(ctx, args)
    local url = args.url or rex.ui.input{ title = "Open in browser", placeholder = "URL, file or localhost:3000" }
    if url == nil then return end
    split_beside(ctx, "browser", "terminal-browser open " .. string.format("%q", url), 0.5)
  end,
}

rex.bind("shift+cmd+k", "browser")

-- rex-fingers: letter hints over paths, URLs and hashes. Its default
-- alt+f would shadow zsh's forward-word, so it lives on cmd+shift+h.
-- scripts/install-rex.sh puts the plugin at this pinned path.
local fingers_lua = HOME .. "/.config/rex/plugins/rex-fingers/lua/rex-fingers/init.lua"
local fingers_file = io.open(fingers_lua)
if fingers_file then
  fingers_file:close()
  dofile(fingers_lua).setup{
    binary     = HOME .. "/.local/bin/rex-fingers",
    key        = "shift+cmd+h",
    window_key = "alt+shift+cmd+h",
    -- Draw hints in a floating pane: TUIs like Claude Code repaint over
    -- hints drawn into the pane itself.
    overlay    = "float",
  }
end

-- Projects. Open a folder as its own session, laid out by where it lives:
-- the first LAYOUTS entry whose root contains the folder wins. Opening a
-- folder that already has a session goes back to that session instead.
local L = rex.layout

local function pane(dir, input)
  return L.block{
    flavor  = SHELL,
    options = { cwd = dir, initial_input = input and (input .. "\n") or nil },
  }
end

local LAYOUTS = {
  -- A repo: agent on the left, shell over files on the right.
  { root = HOME .. "/repos/", layout = function(dir)
      return L.horizontal(0.55, pane(dir, "claude"), L.vertical(0.5, pane(dir), pane(dir, "yazi")))
    end },
  -- Anywhere else: a shell beside files.
  { root = "/", layout = function(dir)
      return L.horizontal(0.6, pane(dir), pane(dir, "yazi"))
    end },
}

local function open_project(dir)
  dir = dir:gsub("/$", "")
  local label = dir == HOME and "home" or dir:match("[^/]+$")
  local list = rex.call("session.list") or {}
  for _, s in ipairs(list.sessions or {}) do
    if s.label == label then
      rex.client.queue("session.select", { session_id = s.session_id })
      return
    end
  end
  for _, rule in ipairs(LAYOUTS) do
    if (dir .. "/"):sub(1, #rule.root) == rule.root then
      local created, err = rex.call("session.create", {
        label = label,
        initial_windows = { { window_label = label, layout = rule.layout(dir) } },
      })
      if err ~= nil then error(err, 0) end
      rex.client.queue("session.select", { session_id = created.session_id })
      return
    end
  end
end

rex.action{
  name     = "project",
  title    = "Open Project…",
  keywords = "project session layout folder repo workspace",
  args     = { dir = "string?" },
  run      = function(ctx, args)
    local dir = args.dir
    if dir == nil then
      -- The picker refuses duplicate ids, and "This folder" is often Home or a repo.
      local items, seen = {}, {}
      local function add(item)
        if not seen[item.id] then seen[item.id] = true; items[#items + 1] = item end
      end
      local here = focused_dir(ctx)
      if here then add{ id = here, title = "This folder", subtitle = here } end
      add{ id = HOME, title = "Home" }
      local ls = rex.exec{ "ls", HOME .. "/repos" }
      for name in ((ls and ls.stdout) or ""):gmatch("[^\n]+") do
        add{ id = HOME .. "/repos/" .. name, title = name }
      end
      local pick = rex.ui.pick{ title = "Open project", placeholder = "Project, or type a path", items = items, allow_other = true }
      if pick == nil then return end
      dir = type(pick) == "table" and (pick.id or pick.text) or pick
      dir = dir:gsub("^~", HOME)
    end
    open_project(dir)
  end,
}

rex.bind("alt+cmd+n", "project")

-- This Mac's own actions and bindings (launch sessions, hosts) go in
-- ~/.config/rex/local.lua, which the dotfiles repo does not track.
local machine = io.open(HOME .. "/.config/rex/local.lua")
if machine then
  machine:close()
  require("local")
end
