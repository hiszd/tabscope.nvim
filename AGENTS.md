# tabscope.nvim - Agent Documentation

## Project Overview

A Neovim plugin providing tab-centric features for a scoped development context. Enables tab-local buffer management, custom tab names, and resession.nvim integration for tab state persistence.

## Plugin Vision

The goal of tabscope.nvim is to provide a tab-scoped context for development in Neovim. Each tab can have its own:
- Custom name
- Buffer list
- Working context

Features include:
- Smart tab labeling with automatic path deduplication
- Tab-scoped buffer lists with navigation
- Buffer conflict detection: when opening a file that exists in another tab, show popup to choose
- Manual tab renaming
- resession.nvim integration for state persistence

## Directory Structure

```
tabscope.nvim/
├── lua/tabscope/                    # Main plugin modules
│   ├── tabscope.lua                 # Main entry point
│   ├── tablabel.lua                 # Smart tab naming
│   ├── bufferlist.lua               # Tab-scoped buffer management
│   ├── bufferlist/
│   │   ├── bufinfo.lua              # BufInfo class with metatable methods
│   │   └── picker.lua               # Picker integration for cwd/open
│   └── utils/
│       └── dict.lua                # Dictionary utilities
├── lua/resession/extensions/        # resession.nvim integration
├── plugin/                          # Plugin entry point (commands)
├── tests/                           # Test suite (plenary/busted)
├── doc/                             # Neovim help documentation
├── .github/workflows/               # CI/CD pipelines
├── Makefile                         # Test runner
├── .stylua.toml                     # Code formatter config
└── README.md                        # Project documentation
```

## Module Architecture

### Main Entry Point
**File**: `lua/tabscope.lua`  
**Purpose**: Public API facade, plugin setup/configuration

### Core Modules

| Module | Path | Purpose |
|--------|------|---------|
| `tabscope` | `lua/tabscope.lua` | Main setup and configuration |
| `tabscope.tablabel` | `lua/tabscope/tablabel.lua` | Smart tab naming (smart path + manual rename) |
| `tabscope.bufferlist` | `lua/tabscope/bufferlist.lua` | Tab-scoped buffer management |
| `tabscope.bufferlist.bufinfo` | `lua/tabscope/bufferlist/bufinfo.lua` | BufInfo class with metatable methods |
| `resession` | `lua/resession/extensions/tabscope.lua` | Extension to save/restore tab-local state |

### BufInfo Class

The `BufInfo` class provides methods for buffer information:

```lua
local BufInfo = require("tabscope.bufferlist.bufinfo")

-- Create from options
local info = BufInfo.new({ file = "/path/to/file.lua", pos = 1 })

-- Create from buffer number
local info = BufInfo.from_buffer(bufnr)

-- Methods
info:get_display_name()  -- Returns display-friendly name
info:get_buffer()        -- Returns buffer number (by filename lookup)
info:is_valid()          -- Checks if buffer is valid
info:set_position(1)     -- Sets position in list
info:to_table()          -- Converts to plain table for serialization
```

### API Style

Each module is independently requireable:

```lua
-- Setup all modules
require("tabscope").setup({
  tablabel = { enable = true },
  bufferlist = { enable = true, hijack = true },
})

-- Or setup individual modules
require("tabscope.tablabel").setup({ enable = true })
require("tabscope.bufferlist").setup({ enable = true, hijack = true })

-- Tab labeling
require("tabscope.tablabel").tabline()     -- returns tabline string
require("tabscope.tablabel").rename_tab()   -- prompts for new name

-- Buffer list
require("tabscope.bufferlist").get(tab_handle?)      -- get buffer list for tab
require("tabscope.bufferlist").add(bufinfo[], tab_handle?)   -- add buffer to tab
require("tabscope.bufferlist").remove(files[], tab_handle?)  -- remove buffer from tab
require("tabscope.bufferlist").restore(bufinfo[], tab_handle?) -- restore from session
require("tabscope.bufferlist").list(tab_handle?)     -- open picker UI
require("tabscope.bufferlist").next(tab_handle?)     -- go to next buffer
require("tabscope.bufferlist").prev(tab_handle?)     -- go to previous buffer
require("tabscope.bufferlist").cwd({scope?})       -- pick working directory
require("tabscope.bufferlist").open({scope?})        -- open file from cwd
```

### Dual-State Architecture

The bufferlist module uses a dual-state architecture:

```
_in_memory: _state[tab] -> dictionary of BufInfo objects (with metatable methods)
_on_disk:   tabpage variable -> plain tables (for resession backup)
```

- All operations read from `_state` (in-memory)
- On mutation, `_state` syncs to tabpage variable
- Session save uses tabpage variable (plain tables serialize correctly)
- Session restore creates new BufInfo objects in `_state`

### Shared Constants

```lua
local tablabel = require("tabscope.tablabel")
tablabel.LABEL_VAR_NAME -- "tabscope_tab_name" - tab-local variable name

local bufferlist = require("tabscope.bufferlist")
bufferlist.BUFFER_VAR_NAME -- "tabscope_buffers" - tab-local buffer list variable name
```

### Autocmd Events

**Custom User Events** - Use `args.data` to access custom data:

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "TabscopeBufAdded",
  callback = function(args)
    local tab = args.data.tab
    local bufs = args.data.bufs
  end,
})
```

**Built-in Neovim Autocmds** - Use direct fields (not `args.data`):

```lua
vim.api.nvim_create_autocmd("BufDelete", {
  callback = function(args)
    _cleanup_handler(args.buf)  -- Direct field, not args.data.buf
  end,
})
```

| Autocmd Type | How to Access Data |
|-------------|-------------------|
| Built-in (BufDelete, BufEnter, etc.) | `args.buf`, `args.file`, etc. |
| User events | `args.data` |

### Module Configuration

Each module has its own `setup()` method and `Config` class:

```lua
---@class tabscope.tablabel.Config
---@field enable boolean Enable smart tab labeling

---@class tabscope.bufferlist.Config
---@field enable boolean Enable tab-scoped buffer management
---@field hijack boolean Show popup when opening file that exists in another tab
---@field picker fun(titles: string[], on_select: fun(index: number))? Custom picker function
---@field cwd_max_depth number Max depth for directory listing in cwd() picker (default: 10)
---@field open_max_depth number Max depth for file listing in open() picker (default: 10)
```

### BufInfo Structure

```lua
---@class tabscope.bufferlist.BufInfo
---@field file string File path (dictionary key)
---@field pos number? Position in buffer list
```

### Buffer Conflict Popup Behavior

When opening a buffer that exists in another tab's buffer list, a popup is shown:

**Popup Options:**
1. **"Switch to existing tab"** - Switch to the tab with the buffer, focusing that buffer
   - Navigates to previous buffer in current tab
   - Removes buffer from current tab's list
   - If current tab had only 1 buffer, the tab is closed after switching

2. **"Keep in current tab"** - Keep the buffer in current tab
   - Removes buffer from other tab's list
   - Buffer stays in current tab's list

**Implementation Details:**
- Uses `BufWinEnter` event to detect when buffers open
- Checks only tracked buffers (via `M.get(tab)`), not all buffers in tab
- Uses `vim.cmd("b#")` to navigate to previous buffer in origin tab
- Emits `TabscopeBufAdded` event when buffer is added to a tab's list

## Code Conventions

### Stylua Configuration
- Column width: 120
- Indent: 2 spaces
- Quotes: double-quoted strings preferred
- Line endings: Unix

### Lua Patterns
- Use `vim.iter` for iteration pipelines
- Use pcall for API calls that may fail
- Prefix internal functions with underscore
- Use vim.schedule for async UI updates

### Naming
- Modules: `snake_case.lua`
- Functions: `snake_case`
- Classes/Types: Use dot-namespaced names matching module path
- Commands: `PascalCase` or `snake_case`

### Class Naming Convention

Use dot-namespaced class names matching the module path:

```lua
---@class tabscope.tablabel.Config
---@field enable boolean Enable smart tab labeling

---@class tabscope.Module
---@field config Config

---@param args tabscope.tablabel.Config
```

### Type Annotations
Use LuaLS annotations:

```lua
---@param opts resession.Extension.OnSaveOpts
---@return any
M.on_save = function(opts)
  ...
end
```

## Testing

**Framework**: plenary.nvim + busted  
**Command**: `make test`  
**Setup**: `tests/minimal_init.lua` (auto-clones plenary if missing)

### Test File Location
```
tests/tabscope/
├── tabscope_spec.lua    # Main module tests
├── tablabel_spec.lua    # Tab label module tests
└── bufferlist_spec.lua # Buffer list module tests
```

## Development Workflow

1. **Create feature branch**: `git checkout -b feature/<name>`
2. **Write tests first** (TDD recommended)
3. **Implement in modules**
4. **Run tests**: `make test`
5. **Check formatting**: `stylua --check lua/`
6. **Commit with conventional messages**

## resession.nvim Integration

The plugin provides a resession extension that:
- Saves tab names per tab on session save
- Saves buffer lists per tab on session save (plain tables)
- Restores tab names and buffer lists after session load via `on_post_load`
- Creates BufInfo objects on restore (metatable reapplied)

Users must register the extension in their resession config:

```lua
require("resession").setup({
  extensions = { tabscope = require("resession.extensions.tabscope") }
})
```

## Implementation Priority

1. **Phase 1**: `tabscope.tablabel` module - smart tab names ✓
2. **Phase 2**: `tabscope.bufferlist` module - tab-scoped buffer management ✓
3. **Phase 3**: Bug fixes and polish
4. **Phase 4**: Tab working directory
   - `bufferlist.cwd()` - pick working directory (tab or global)
   - `bufferlist.open()` - open file from cwd, switch tabs if file belongs to another tab's cwd
   - `bufferlist.picker` module - handles picker integration (snacks > telescope > vim.ui.select)

## Common Tasks

### Running Tests
```bash
make test
```

### Running Stylua
```bash
stylua lua/
```

### Adding a New Module
1. Create `lua/tabscope/<module>.lua`
2. Add public API functions
3. Add tests in `tests/tabscope/<module>_spec.lua`
4. Update this AGENTS.md

## Notes

- This is a "beginning phase" project - structure may evolve
- Keep modules focused and single-purpose
- Avoid adding external dependencies without discussion
- Session data storage is handled by resession.nvim, not this plugin
- Custom pickers can be specified in module configuration
- Each module can emit events for extensibility
- Uses vim.iter patterns throughout for cleaner iteration
- BufInfo objects use metatables for in-memory operations, serialize to plain tables for storage