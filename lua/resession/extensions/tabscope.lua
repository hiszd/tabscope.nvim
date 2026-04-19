local M = {}

local tablabel = require("tabscope.tablabel")

---Get the saved data for this extension
---@param opts resession.Extension.OnSaveOpts Information about the session being saved
---@return any
M.on_save = function(opts)
  local names = {}
  for _, tab_handle in ipairs(vim.api.nvim_list_tabpages()) do
    local success, name = pcall(vim.api.nvim_tabpage_get_var, tab_handle, tablabel.LABEL_VAR_NAME)
    if success and name then
      names[tostring(tab_handle)] = name
    end
  end
  return { names = names }
end

---@class TabnameData
---@field names table<string, string>

---Restore the extension state
---@param data TabnameData #The value returned from on_save
M.on_post_load = function(data)
  -- This is run after the buffers, windows, and tabs are restored
  for tab, name in pairs(data.names) do
    -- Resession handles mapping the saved tab handles to the new ones
    vim.api.nvim_tabpage_set_var(tonumber(tab), tablabel.LABEL_VAR_NAME, name)
  end
  vim.cmd("redrawtabline")
end

return M
