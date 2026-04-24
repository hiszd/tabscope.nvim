---Tab label module providing smart tab naming.
---Uses smart path deduplication when tabs share filenames.
---Emits: TabscopeTabRenamed after tab rename.
---
---@usage
---  require("tabscope.tablabel").setup({ enable = true })
---  vim.cmd("TabRename") -- or :TabRename
---
---@class tabscope.tablabel.Module
local M = {}

---Tab-local variable name for storing custom tab names.
---Used by resession extension to persist tab names.
---@export LABEL_VAR_NAME
M.LABEL_VAR_NAME = "tabscope_tab_name"

---Prompt for a new tab name and apply it to the current tab.
---Emits TabscopeTabRenamed event after rename.
---
---@usage
---  require("tabscope.tablabel").rename_tab()
---  vim.cmd("TabRename")
M.rename_tab = function()
  local new_name = vim.fn.input("New Tab Name: ")
  local tab_handle = vim.api.nvim_get_current_tabpage()
  vim.api.nvim_tabpage_set_var(tab_handle, M.LABEL_VAR_NAME, ((new_name ~= "") and new_name or nil))

  -- Emit custom event for other plugins
  vim.api.nvim_exec_autocmds("User", {
    pattern = "TabscopeTabRenamed",
    data = { tab = tab_handle, name = new_name },
  })
  vim.cmd("redrawtabline")
end

---Get the smart tab label for a tab.
---Checks custom name first, then generates unique path if needed.
---@param tab_handle number Tab handle
---@param tab_index number Tab index (1-based)
---@return string Label for display
local function get_smart_tab_label(tab_handle, tab_index)
  -- 1. Check for the tab-local variable first
  -- We use pcall because accessing a non-existent var on a tab can throw an error
  local has_custom, custom_name = pcall(vim.api.nvim_tabpage_get_var, tab_handle, M.LABEL_VAR_NAME)
  if has_custom and custom_name then
    return custom_name
  end

  -- 2. Logic for unique path resolution (same as before)
  local bufnr = vim.fn.tabpagebuflist(tab_index)[1]
  local full_path = vim.api.nvim_buf_get_name(bufnr)

  if full_path == "" then
    return "[No Name]"
  end

  local filename = vim.fn.fnamemodify(full_path, ":t")

  local conflict = vim
    .iter(vim.api.nvim_list_tabpages())
    :filter(function(tab)
      return tab ~= tab_handle
    end)
    :any(function(tab)
      local other_buf = vim.fn.tabpagebuflist(tab)[1]
      return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(other_buf), ":t") == filename
    end)

  if not conflict then
    return filename
  end

  local parts = vim.split(full_path, "/", { trimempty = true })
  local label = filename

  for i = #parts - 1, 1, -1 do
    label = parts[i] .. "/" .. label
    local unique = not vim
      .iter(vim.api.nvim_list_tabpages())
      :filter(function(tab)
        return tab ~= tab_handle
      end)
      :any(function(tab)
        local o_buf = vim.fn.tabpagebuflist(tab)[1]
        return vim.api.nvim_buf_get_name(o_buf):sub(-#label) == label
      end)
    if unique then
      break
    end
  end
  return label
end

---Generate tabline string with smart labels.
---@return string Tabline suitable for vim.opt.tabline
---
---@usage
---  vim.opt.tabline = "%!v:lua.require('tabscope.tablabel').tabline()"
M.tabline = function()
  local tabs = vim.api.nvim_list_tabpages()
  local s = vim.iter(tabs):enumerate():fold("", function(acc, i, tab_handle)
    if tab_handle == vim.api.nvim_get_current_tabpage() then
      acc = acc .. "%#TabLineSel#"
    else
      acc = acc .. "%#TabLine#"
    end
    -- Pass the handle and the index to the label generator
    acc = acc .. " " .. get_smart_tab_label(tab_handle, i) .. " "
    return acc
  end)
  return s .. "%#TabLineFill#"
end

---@class tabscope.tablabel.Config
---@field enable boolean Enable smart tab labeling (default: true)
M.config = {
  enable = true,
}

---Setup the tablabel module.
---@param args tabscope.tablabel.Config?
---
---@usage
---  require("tabscope.tablabel").setup({ enable = true })
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
  if M.config.enable then
    vim.opt.tabline = "%!v:lua.require('tabscope.tablabel').tabline()"
  end
end

return M
