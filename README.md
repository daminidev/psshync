# Projects SSH Sync (Psshync) (WIP !! DO NOT USE)

Auto upload the changes made in your projects (file writes) to another machine with ssh


## Requirements

* ssh with password less access to another server where you want to upload changes


## TODO :

* use async upload
* show the upload status (fail/succes) directly on the status line
* implement a way to view diffs
* show a popup for the output of the PsshyncDiff command ?
* 

## Usage

The following commands are available :

* PsshyncEnable : Enable the sync
* PsshyncDisable : Disable the sync
* PsshyncIsEnabled : Print the current sync status
* PsshyncToggle : Toggle the sync on/off
* PsshyncGetEnabled : returns the current status (can be used for status line)
* PsshyncDiff : Prints either «Files are identical» or «Files differs» (md5sum is done on local and distant file)


### Lazy package manager config example in nvChad :

#### load the plugin :

Load the plugin in lua/custom/plugins.lua :

```lua
local plugins = {

  {
    "daminidev/psshync",
    lazy = false,
    dependencies = {
      "MunifTanjim/nui.nvim"
    },
    config = function()
      require("custom.configs.psshyng")
    end
  },
-- rest of plugins
```

In custom/configs/psshync.lua :

```lua
local psshyng = require "psshync"

psshyng.setup {
  debug = false,
  projects = {
    {
      name = "Project One",
      enabled = true,
      sourcePath = "/home/username/project_one",
      destPath = "/home/distantUser/project_one",
      sshUser = "distantUser",
      sshAddress = "192.168.1.10",
    },
    {
      name = "Project Two",
      enabled = true,
      sourcePath = "/home/username/project_two",
      destPath = "/home/ubuntu/project-two",
      sshUser = "ubuntu",
      sshAddress = "192.168.1.15",
    }
  }
}
```

For a realtime view of the plugin’s activation status in the status line, in my chadrc.lua :

```lua

 statusline = {
    -- modules arg here is the default table of modules
    overriden_modules = function(modules)

      table.insert(
        modules,
        4,
        (function()
          local ps = require "psshync"
          local path = vim.api.nvim_buf_get_name(stbufnr())
          local res = ps.getEnabled(path)
          local pos = string.find(res, "ON", 1, true)
          if pos then
            return " %#St_ReplaceMode#¯é╝ " .. res .. " %#St_ReplaceModeSep#¯é╝%#ST_EmptySpace#¯é╝%#St_file_sep#¯é╝"
          else
            return "%#ST_File_Sep#" .. res
          end
        end)()
      )

    end,
  },


```


## Why ?

Some of our dev environements are on another linux machine (that’s nice and painfull at the same time). So I need something to push files on this env as soon as it’s saved on the local filesystem.

- It’s fun to try and learn, so why not ?
- I want to be able to control how this sync works
- There are a myriad of alternatives that could probably work better for my use case. I did not try Inotify-wait and entr but I did try lsyncd (which is awesome) but there’s some lag (3 - 5 sec delay) after save. (Feel free to suggest alternatives)
