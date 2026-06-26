local M = {}

local tablabel = require("tabscope.tablabel")
local bufferlist = require("tabscope.bufferlist")

---Save tabscope state keyed by tab position (1, 2, 3...) instead of tab handle.
---Tab handles change across sessions, but tabs are restored in the same order,
---so positional indexing is stable.
M.on_save = function()
  local data = {}
  local tabpages = vim.api.nvim_list_tabpages()

  if tablabel.config.enable then
    local labels = {}
    for i, tab_handle in ipairs(tabpages) do
      local ok, name = pcall(vim.api.nvim_tabpage_get_var, tab_handle, tablabel.LABEL_VAR_NAME)
      if ok and name then
        table.insert(labels, { pos = i, name = name })
      end
    end
    data.tablabel = labels
  end

  if bufferlist.config.enable then
    local lists = {}
    for i, tab_handle in ipairs(tabpages) do
      local ok, buffers = pcall(vim.api.nvim_tabpage_get_var, tab_handle, bufferlist.BUFFER_VAR_NAME)
      if ok and buffers then
        table.insert(lists, { pos = i, buffers = buffers })
      end
    end
    data.bufferlist = lists
  end

  return data
end

---Restore tabscope state, matching saved data to restored tabs by position.
---Supports both the old format (keyed by tostring(tab_handle)) and the new
---position-based format for backward compatibility.
M.on_post_load = function(data)
  if not data then return end

  local tabpages = vim.api.nvim_list_tabpages()

  if tablabel.config.enable and data.tablabel then
    local first_key = next(data.tablabel)
    if first_key and type(first_key) == "string" then
      for tab_str, label in pairs(data.tablabel) do
        local t = tonumber(tab_str)
        if t then
          pcall(vim.api.nvim_tabpage_set_var, t, tablabel.LABEL_VAR_NAME, label)
        end
      end
    else
      for _, entry in ipairs(data.tablabel) do
        local tab_handle = tabpages[entry.pos]
        if tab_handle then
          pcall(vim.api.nvim_tabpage_set_var, tab_handle, tablabel.LABEL_VAR_NAME, entry.name)
        end
      end
    end
    vim.cmd("redrawtabline")
  end

  if bufferlist.config.enable and data.bufferlist then
    local first_key = next(data.bufferlist)
    if first_key and type(first_key) == "string" then
      for tab_str, list in pairs(data.bufferlist) do
        local t = tonumber(tab_str)
        if not t then break end
        local r = vim.iter(list):fold({}, function(acc, _, info)
          table.insert(acc, info)
          return acc
        end)
        bufferlist.restore(r, t)
      end
    else
      for _, entry in ipairs(data.bufferlist) do
        local tab_handle = tabpages[entry.pos]
        if not tab_handle then break end
        local r = vim.iter(entry.buffers):fold({}, function(acc, _, info)
          table.insert(acc, info)
          return acc
        end)
        bufferlist.restore(r, tab_handle)
      end
    end
  end
end

return M
