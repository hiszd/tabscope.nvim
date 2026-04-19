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
  local all_tabs = vim.api.nvim_list_tabpages()
  local conflict = false

  for i, _ in ipairs(all_tabs) do
    if i ~= tab_index then
      local other_buf = vim.fn.tabpagebuflist(i)[1]
      local other_path = vim.api.nvim_buf_get_name(other_buf)
      if vim.fn.fnamemodify(other_path, ":t") == filename then
        conflict = true
        break
      end
    end
  end

  if not conflict then
    return filename
  end

  local parts = vim.split(full_path, "/", { trimempty = true })
  local label = filename

  for i = #parts - 1, 1, -1 do
    label = parts[i] .. "/" .. label
    local unique = true
    for j, _ in ipairs(all_tabs) do
      if j ~= tab_index then
        local o_buf = vim.fn.tabpagebuflist(j)[1]
        local o_path = vim.api.nvim_buf_get_name(o_buf)
        if o_path:sub(-#label) == label then
          unique = false
          break
        end
      end
    end
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
  local s = ""
  local tabs = vim.api.nvim_list_tabpages()
  for i, tab_handle in ipairs(tabs) do
    if tab_handle == vim.api.nvim_get_current_tabpage() then
      s = s .. "%#TabLineSel#"
    else
      s = s .. "%#TabLine#"
    end
    -- Pass the handle and the index to the label generator
    s = s .. " " .. get_smart_tab_label(tab_handle, i) .. " "
  end
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
