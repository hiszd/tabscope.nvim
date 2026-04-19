---Tab-scoped buffer list management module.
---Provides tab-local buffer lists with navigation, reordering, and buffer hijack.
---@usage
---  require("tabscope.bufferlist").setup({ enable = true })
---  require("tabscope.bufferlist").list() -- open picker
---  require("tabscope.bufferlist").next() -- next buffer
---  require("tabscope.bufferlist").prev() -- previous buffer
---
---@class tabscope.bufferlist.Module
local M = {}

---Buffer list variable name.
M.BUFFER_VAR_NAME = "tabscope_buffers"

---@class tabscope.bufferlist.Config
---@field enable boolean Enable tab-scoped buffer management (default: true)
---@field hijack boolean Automatically switch to tab with open buffer when opening file (default: true)
---@field picker fun(titles: string[], on_select: fun(index: number))? Custom picker function
M.config = {
  enable = true,
  hijack = true,
  picker = nil,
}

---Get buffer list for a tab.
---Initializes with current buffer if empty.
---@param tab_handle number? Tab handle (defaults to current tab)
---@return number[] Ordered list of buffer numbers
M.get = function(tab_handle)
  local tab = tab_handle or vim.api.nvim_get_current_tabpage()
  local success, buffers = pcall(vim.api.nvim_tabpage_get_var, tab, M.BUFFER_VAR_NAME)
  if not success or type(buffers) ~= "table" or #buffers == 0 then
    local current_buf = vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_is_valid(current_buf) then
      vim.api.nvim_tabpage_set_var(tab, M.BUFFER_VAR_NAME, { current_buf })
      return { current_buf }
    end
    return {}
  end
  return buffers
end

---Add buffer to tab's buffer list.
---@param bufnr number? Buffer number (defaults to current buffer)
---@param tab_handle number? Tab handle (defaults to current tab)
M.add = function(bufnr, tab_handle)
  local buf = bufnr or vim.api.nvim_get_current_buf()
  local tab = tab_handle or vim.api.nvim_get_current_tabpage()
  local buffers = M.get(tab)

  for _, b in ipairs(buffers) do
    if b == buf then
      return
    end
  end

  table.insert(buffers, buf)
  vim.api.nvim_tabpage_set_var(tab, M.BUFFER_VAR_NAME, buffers)

  -- Emit event for other plugins to react
  vim.api.nvim_exec_autocmds("User", {
    pattern = "TabscopeBufAdded",
    data = { buf = buf, tab = tab },
  })
end

---Remove buffer from tab's buffer list.
---@param bufnr number? Buffer number (defaults to current buffer)
---@param tab_handle number? Tab handle (defaults to current tab)
M.remove = function(bufnr, tab_handle)
  local buf = bufnr or vim.api.nvim_get_current_buf()
  local tab = tab_handle or vim.api.nvim_get_current_tabpage()
  local buffers = M.get(tab)

  for i, b in ipairs(buffers) do
    if b == buf then
      table.remove(buffers, i)
      vim.api.nvim_tabpage_set_var(tab, M.BUFFER_VAR_NAME, buffers)

      -- Emit event for other plugins to react
      vim.api.nvim_exec_autocmds("User", {
        pattern = "TabscopeBufRemoved",
        data = { buf = buf, tab = tab },
      })
      return
    end
  end
end

---Cleanup closed buffers from all tab buffer lists.
local function _cleanup_handler(buf)
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local buffers = M.get(tab)
    local new_buffers = {}
    for _, b in ipairs(buffers) do
      if b ~= buf and vim.api.nvim_buf_is_valid(b) then
        table.insert(new_buffers, b)
      end
    end
    vim.api.nvim_tabpage_set_var(tab, M.BUFFER_VAR_NAME, new_buffers)
  end
end

---Check if buffer exists in any tab's list.
---Searches all tabs to find which tab has the buffer.
---@param buf number Buffer number to search for
---@return number? Tab handle if found, nil otherwise
local function _find_buffer(buf)
  -- Iterate through all open tabs
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    -- Get buffer list for this tab
    local buffers = M.get(tab)
    -- Check each buffer in the list
    for _, b in ipairs(buffers) do
      if b == buf then
        return tab
      end
    end
  end
  return nil
end

-- Track if we're currently hijacking (prevents re-triggering)
local hijack_in_progress = false

---Handle buffer hijack on BufReadPre.
---Only acts on filesystem files (not internal neovim buffers).
---If found in another tab's list, switches to that tab.
---Otherwise adds to current tab's list.
local function _hijack_handler(args)
  -- Skip if hijack is disabled in config
  if not M.config.hijack then
    return
  end

  -- Get the file path being read using vim.fn.expand
  -- BufReadPre doesn't provide args.data.buf, so we use expand
  local path = vim.fn.expand("%:p")
  if path == "" then
    return
  end

  -- Verify file actually exists on the filesystem
  -- Skip if file doesn't exist (e.g., was deleted or is a new file)
  if vim.fn.filereadable(path) == 0 then
    return
  end

  -- Get buffer handle for this file path
  local buf = vim.fn.bufnr(path)
  if buf <= 0 then
    -- Buffer doesn't exist yet - nothing to hijack
    return
  end

  -- Skip if buffer handle is invalid
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  -- Search all tabs to see if this buffer is already tracked
  local target_tab = _find_buffer(buf)
  if target_tab then
    -- Found in another tab → switch to that tab
    hijack_in_progress = true
    vim.api.nvim_set_current_tabpage(target_tab)
    hijack_in_progress = false
    return
  end

  -- Not found elsewhere → add to current tab's list
  local current_tab = vim.api.nvim_get_current_tabpage()
  local buffers = M.get(current_tab)

  -- Skip if already in current tab's list (prevent duplicates)
  for _, b in ipairs(buffers) do
    if b == buf then
      return
    end
  end

  -- Add buffer to current tab's list
  table.insert(buffers, buf)
  vim.api.nvim_tabpage_set_var(current_tab, M.BUFFER_VAR_NAME, buffers)

  -- Emit event for other plugins to react
  vim.api.nvim_exec_autocmds("User", {
    pattern = "TabscopeBufAdded",
    data = { buf = buf, tab = current_tab },
  })
end

---Navigate to next buffer in tab's list.
---@param tab_handle number? Tab handle (defaults to current tab)
M.next = function(tab_handle)
  local tab = tab_handle or vim.api.nvim_get_current_tabpage()
  local buffers = M.get(tab)

  if #buffers <= 1 then
    return
  end

  local current_buf = vim.api.nvim_get_current_buf()
  local current_idx = 1

  for i, buf in ipairs(buffers) do
    if buf == current_buf then
      current_idx = i
      break
    end
  end

  local next_idx = (current_idx % #buffers) + 1
  vim.api.nvim_win_set_buf(0, buffers[next_idx])
end

---Navigate to previous buffer in tab's list.
---@param tab_handle number? Tab handle (defaults to current tab)
M.prev = function(tab_handle)
  local tab = tab_handle or vim.api.nvim_get_current_tabpage()
  local buffers = M.get(tab)

  if #buffers <= 1 then
    return
  end

  local current_buf = vim.api.nvim_get_current_buf()
  local current_idx = 1

  for i, buf in ipairs(buffers) do
    if buf == current_buf then
      current_idx = i
      break
    end
  end

  local prev_idx = current_idx - 1
  if prev_idx < 1 then
    prev_idx = #buffers
  end
  vim.api.nvim_win_set_buf(0, buffers[prev_idx])
end

---Get buffer titles for picker.
---@param tab_handle number? Tab handle
---@return string[] Buffer names for display
local function _get_titles(tab_handle)
  local tab = tab_handle or vim.api.nvim_get_current_tabpage()
  local buffers = M.get(tab)
  local titles = {}

  for _, buf in ipairs(buffers) do
    if vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      local title = name ~= "" and vim.fn.fnamemodify(name, ":.") or "[No Name]"
      table.insert(titles, title)
    end
  end

  return titles
end

---Open buffer list picker.
---@param tab_handle number? Tab handle (defaults to current tab)
M.list = function(tab_handle)
  local tab = tab_handle or vim.api.nvim_get_current_tabpage()
  local buffers = M.get(tab)

  if #buffers == 0 then
    vim.notify("No buffers in tab", vim.log.levels.INFO)
    return
  end

  local titles = _get_titles(tab)
  local picker = M.config.picker or vim.ui.select

  picker(titles, { prompt = "Select buffer:" }, function(choice)
    if not choice then
      return
    end

    for i, title in ipairs(titles) do
      if title == choice then
        local win = vim.api.nvim_tabpage_get_win(tab)
        vim.api.nvim_win_set_buf(win, buffers[i])
        -- Emit event for other plugins to react
        vim.api.nvim_exec_autocmds("User", {
          pattern = "TabscopeBufSelected",
          data = { buf = buffers[i], tab = tab },
        })
        return
      end
    end
  end)
end

---Open buffer reordering UI.
---@param tab_handle number? Tab handle (defaults to current tab)
M.reorder = function(tab_handle)
  local tab = tab_handle or vim.api.nvim_get_current_tabpage()
  local buffers = M.get(tab)

  if #buffers == 0 then
    vim.notify("No buffers to reorder", vim.log.levels.INFO)
    return
  end

  local titles = _get_titles(tab)

  vim.ui.select(titles, { prompt = "Move buffer to position:", kind = "reorder" }, function(choice, idx)
    if not choice or not idx then
      return
    end

    local function moveItem(fromIdx, toIdx)
      local item = table.remove(buffers, fromIdx)
      table.insert(buffers, toIdx, item)
    end

    for i, title in ipairs(titles) do
      if title == choice then
        moveItem(i, idx)
        vim.api.nvim_tabpage_set_var(tab, M.BUFFER_VAR_NAME, buffers)
        return
      end
    end
  end)
end

---Setup the bufferlist module.
---@param args tabscope.bufferlist.Config?
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})

  -- Create BufReadPre autocmd if hijack is enabled
  -- BufReadPre fires before reading a file from disk (not on tab switches)
  if M.config.hijack then
    vim.api.nvim_create_autocmd("BufReadPre", {
      callback = _hijack_handler,
    })
  end

  -- Cleanup: remove closed buffers from all tab lists
  vim.api.nvim_create_autocmd("BufDelete", {
    callback = function(args)
      -- Note: For built-in autocmds like BufDelete, use args.buf (not args.data.buf)
      _cleanup_handler(args.buf)
    end,
  })
end

return M
