# tabscope.nvim

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)

A Neovim plugin for smart tab labeling with resession.nvim integration.

## Setup

```lua
-- Enable tab labeling (sets vim.opt.tabline)
require("tabscope.tablabel").setup({ enable = true })

-- Or use the main module
require("tabscope").setup({ tablabel = { enable = true } })
```

## Commands

- `:TabLabel` - Show current tabline (for debugging)
- `:TabRename` - Rename current tab

## Autocmd Events

After renaming a tab, the `TabscopeTabRenamed` event is emitted:

```lua
vim.api.nvim_create_autocmd("TabscopeTabRenamed", {
  callback = function(args)
    local tab = args.data.tab      -- tab handle
    local name = args.data.name  -- new name
    -- e.g., save session
    require("resession").save(vim.fn.getcwd(), { dir = "dirsession" })
  end,
})
```

## resession.nvim Integration

Register the extension in your resession config:

```lua
require("resession").setup({
  extensions = { tabscope = require("resession.extensions.tabscope") }
})
```

## Features

- Smart tab labeling (deduplicates filenames)
- Custom tab names (manual rename)
- resession.nvim extension for tab state persistence
- Extensible via autocmd events
