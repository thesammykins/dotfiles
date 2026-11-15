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

-- This Mac's own actions and bindings (launch sessions, hosts) go in
-- ~/.config/rex/local.lua, which the dotfiles repo does not track.
local machine = io.open(HOME .. "/.config/rex/local.lua")
if machine then
  machine:close()
  require("local")
end
