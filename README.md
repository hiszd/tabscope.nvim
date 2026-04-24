# tabscope.nvim

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)

A Neovim plugin for tab-centric development context. Each tab has its own buffer list, custom name, and smart path deduplication. Integrates with resession.nvim for persistence.

## Features

- Smart tab labeling (deduplicates filenames across tabs)
- Tab-scoped buffer lists with navigation
- Buffer conflict detection (popup when file exists in another tab)
- Manual tab renaming
- resession.nvim integration for state persistence

## Setup

```lua
-- Full setup (recommended)
require("tabscope").setup({
  tablabel = { enable = true },
  bufferlist = { enable = true, hijack = true },
})

-- Or individual modules
require("tabscope.tablabel").setup({ enable = true })
require("tabscope.bufferlist").setup({ enable = true, hijack = true })
```

## Configuration

| Module | Option | Type | Default | Description |
|--------|--------|------|---------|-------------|
| `tablabel` | `enable` | boolean | `true` | Enable smart tab labeling |
| `bufferlist` | `enable` | boolean | `true` | Enable buffer list management |
| `bufferlist` | `hijack` | boolean | `true` | Show conflict popup |
| `bufferlist` | `picker` | function? | `nil` | Custom picker function |

## Commands

| Command | Module | Description |
|---------|--------|-------------|
| `:TabLabel` | tablabel | Show/refresh tabline |
| `:TabRename` | tablabel | Rename current tab |
| `:TabBufList` | bufferlist | Open buffer picker |
| `:TabBufNext` | bufferlist | Go to next buffer |
| `:TabBufPrev` | bufferlist | Go to previous buffer |

## API Reference

### tablabel Module

```lua
local tablabel = require("tabscope.tablabel")

tablabel.LABEL_VAR_NAME  -- "tabscope_tab_name" - stored in tab
tablabel.config       -- current configuration

tablabel.tabline()       -- returns tabline string
tablabel.rename_tab()     -- prompts for new name (interactive)
tablabel.setup({ enable = true/false })
```

### bufferlist Module

```lua
local bufferlist = require("tabscope.bufferlist")

bufferlist.BUFFER_VAR_NAME  -- "tabscope_buffers" - stored in tab
bufferlist.config         -- current configuration

-- Get buffer list for tab
bufferlist.get(tab_handle?)  -- returns table<string, BufInfo>

-- Add buffers to tab
bufferlist.add({{{ buf, win, file, pos? }}}, tab_handle?)

-- Remove buffers from tab
bufferlist.remove({"file.lua", ...}, tab_handle?)

-- Restore buffers from session
bufferlist.restore({{{ buf, win, file, pos? }}}, tab_handle?)

-- Open buffer picker
bufferlist.list(tab_handle?)

-- Navigate buffers
bufferlist.next(tab_handle?)
bufferlist.prev(tab_handle?)

bufferlist.setup({ enable, hijack, picker })
```

### BufInfo Structure

```lua
---@class tabscope.bufferlist.BufInfo
---@field buf number Buffer number
---@field win number Window number
---@field file string File path (dictionary key)
---@field pos number? Position in buffer list
```

### Main Module

```lua
local tabscope = require("tabscope")

tabscope.config     -- merged configuration
tabscope.setup({ tablabel = {}, bufferlist = {} })
```

## Autocmd Events

| Event | Data | Description |
|-------|------|-------------|
| `TabscopeBufAdded` | `{ tab, buffers }` | Buffer added to list |
| `TabscopeBufRemoved` | `{ tab, buffers }` | Buffer removed from list |
| `TabscopeBufSelected` | `{ tab, buffer }` | Buffer selected in picker |
| `TabscopeBufRestored` | `{ tab, buffers }` | Buffers restored from session |
| `TabscopeTabRenamed` | `{ tab, name }` | Tab renamed |

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "TabscopeBufAdded",
  callback = function(args)
    local tab = args.data.tab
    local buffers = args.data.buffers
  end,
})
```

## resession.nvim Integration

Register in your resession config:

```lua
require("resession").setup({
  extensions = { tabscope = require("resession.extensions.tabscope") }
})
```

When saving/restoring sessions, tab names and buffer lists persist automatically.

## Buffer Conflict Popup

When opening a file that exists in another tab's list:

1. **"Switch to existing tab"** - Switch to tab with the buffer, close current tab if it had only that buffer
2. **"Keep in current tab"** - Keep buffer in current tab, remove from other tab

## Development

```bash
make test      -- run tests
stylua lua/   -- format code
```