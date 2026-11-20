-- Managed by milo setup.
pcall(dofile, "/Users/samanthamyers/.config/milo/rex.lua")
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

-- Milo: Warp-style project rail (outline, history, usage) on the left.
-- Its actions come from the managed dofile at the top of this file.
rex.bind("shift+cmd+e", "milo_layout")
rex.bind("shift+cmd+o", "milo_peek_outline")

-- Edit the file milo's reader is showing. Milo has no editor setting, but
-- its floating reader runs `milo view PATH`, so this swaps the reader for
-- $EDITOR (set in .zshrc, hence zsh -i) on the same file, in the same spot.
local function milo_reader_path(ctx)
  local proc, err = rex.call("block.method", {
    session_id = ctx.session_id, block_id = ctx.block_id, method = "process",
  })
  if err ~= nil then error(err, 0) end
  local pid = proc and proc.child and proc.child.pid
  if pid == nil then return nil end
  local kids = rex.exec{ "pgrep", "-P", tostring(math.floor(pid)) }
  local child = kids and kids.stdout:match("%d+")
  if child == nil then return nil end
  local ps = rex.exec{ "ps", "-o", "args=", "-p", child }
  local args = ps and ps.stdout or ""
  if args:find(" %-%-commit ") then return nil, "This is a past version from History; open it from the outline to edit." end
  return args:match("milo view (.-)%s*$")
end

rex.action{
  name     = "milo_edit",
  title    = "Milo: Edit File in $EDITOR",
  keywords = "milo reader editor open edit",
  run      = function(ctx)
    local path, why = milo_reader_path(ctx)
    if path == nil then error(why or "Focus a milo reader first.", 0) end
    local _, err = rex.session.new_layer{
      bounds = { 0.12, 0.08, 0.76, 0.84 },
      focus  = true,
      layout = rex.layout.block{
        flavor  = SHELL,
        label   = path:match("[^/]+$"),
        options = {
          shell   = "none",
          command = { "/bin/zsh", "-ic", 'exec "${VISUAL:-$EDITOR}" "$1"', "edit", path },
          exit    = { on_completion = true },
        },
      },
    }
    if err ~= nil then error(err, 0) end
    rex.call("block.close", { session_id = ctx.session_id, block_id = ctx.block_id })
  end,
}

rex.bind("cmd+e", "milo_edit")

-- This Mac's own actions and bindings (launch sessions, hosts) go in
-- ~/.config/rex/local.lua, which the dotfiles repo does not track.
local machine = io.open(HOME .. "/.config/rex/local.lua")
if machine then
  machine:close()
  require("local")
end
