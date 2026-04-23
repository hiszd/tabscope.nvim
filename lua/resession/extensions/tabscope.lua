local M = {}

local tablabel = require("tabscope.tablabel")
local bufferlist = require("tabscope.bufferlist")

---@class TabScopeData
---@field tablabel TabLabelData
---@field bufferlist BufferListData

---@alias BufferListData table<string, table<string, tabscope.bufferlist.BufInfo>>

---@alias TabLabelData table<string, string>

---Get the saved data for this extension
---@param opts resession.Extension.OnSaveOpts Information about the session being saved
---@return TabScopeData
M.on_save = function(opts)
  local data = {
    tablabel = (function()
      if tablabel.config.enable == true then
        local list = {}
        for _, tab_handle in ipairs(vim.api.nvim_list_tabpages()) do
          local success, name = pcall(vim.api.nvim_tabpage_get_var, tab_handle, tablabel.LABEL_VAR_NAME)
          if success and name then
            list[tostring(tab_handle)] = name
          end
        end
        return list
      end
    end)(),
    bufferlist = (function()
      if bufferlist.config.enable == true then
        local list = {}
        for _, tab_handle in ipairs(vim.api.nvim_list_tabpages()) do
          local success, buffers = pcall(vim.api.nvim_tabpage_get_var, tab_handle, bufferlist.BUFFER_VAR_NAME)
          if success and buffers then
            list[tostring(tab_handle)] = buffers
          end
        end
        return list
      end
    end)(),
  }

  print("saving session")
  print(vim.inspect(data))

  return data
end

---Restore the extension state
---@param data TabScopeData #The value returned from on_save
M.on_post_load = function(data)
  print("restoring tabscope")
  if tablabel.config.enable == true then
    print("restoring tablabel")
    print(vim.inspect(data.tablabel))
    -- This is run after the buffers, windows, and tabs are restored
    for tab, label in pairs(data.tablabel) do
      local t = tonumber(tab)
      if not t then
        return
      end
      -- Resession handles mapping the saved tab handles to the new ones
      vim.api.nvim_tabpage_set_var(t, tablabel.LABEL_VAR_NAME, label)
    end
    vim.cmd("redrawtabline")
  end
  if bufferlist.config.enable == true then
    print("restoring bufferlist")
    print(vim.inspect(data.bufferlist))
    -- This is run after the buffers, windows, and tabs are restored
    for tab, list in pairs(data.bufferlist) do
      local t = tonumber(tab)
      if not t then
        return
      end
      -- Resession handles mapping the saved tab handles to the new ones
      vim.api.nvim_tabpage_set_var(t, bufferlist.BUFFER_VAR_NAME, list)
    end
  end
end

return M
