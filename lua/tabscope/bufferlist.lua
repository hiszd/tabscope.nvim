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

local dict = require("tabscope.utils.dict")

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
---Returns a dictionary with buffer numbers as keys and BufInfo as values.
---@param tab_handle number? # Tab handle (defaults to current tab)
---@return table<string, tabscope.bufferlist.BufInfo> # Dictionary of buffer info keyed by buffer number
M.get = function(tab_handle)
  local tab = tab_handle or vim.api.nvim_get_current_tabpage()
  local success, buffers = pcall(vim.api.nvim_tabpage_get_var, tab, M.BUFFER_VAR_NAME)
  if not success or type(buffers) ~= "table" then
    return {}
  end
  return buffers
end

--- Buffer information
---@class tabscope.bufferlist.BufInfo
---@field buf number Buffer number (also used as dictionary key)
---@field win number Window number
---@field file string File path
---@field pos number? Array position in the buffer list

local getbufinfo = function(bufnr, position)
  if vim.api.nvim_buf_is_valid(bufnr) == false then
    return nil
  end
  return {
    buf = bufnr,
    win = vim.fn.bufwinid(bufnr),
    file = vim.api.nvim_buf_get_name(bufnr),
    pos = position or 0,
  }
end

---Add buffer to tab's buffer list.
---@param bufinfo [tabscope.bufferlist.BufInfo] Buffer number (defaults to current buffer)
---@param tab_handle number? Tab handle (defaults to current tab)
M.add = function(bufinfo, tab_handle)
  local tab = tab_handle or vim.api.nvim_get_current_tabpage()
  local buffers = M.get(tab)

  local position = dict.count(buffers) + 1

  for _, bufin in pairs(bufinfo) do
    if not bufin.pos then
      bufin.pos = position
      position = position + 1
    end
    buffers[tostring(bufin.buf)] = bufin
    print("created buffer with these values: " .. vim.inspect(bufin))
  end

  vim.api.nvim_tabpage_set_var(tab, M.BUFFER_VAR_NAME, buffers)

  -- Emit event for other plugins to react
  vim.api.nvim_exec_autocmds("User", {
    pattern = "TabscopeBufAdded",
    data = { bufs = buffers, tab = tab },
  })
end

---Remove buffer from tab's buffer list.
---@param bufnr number? Buffer number (defaults to current buffer)
---@param tab_handle number? Tab handle (defaults to current tab)
---@return boolean
M.remove = function(bufnr, tab_handle)
  local buf = bufnr or vim.api.nvim_get_current_buf()
  local tab = tab_handle or vim.api.nvim_get_current_tabpage()
  local buffers = M.get(tab)

  if not buffers[tostring(buf)] then
    return false
  end

  buffers[tostring(buf)] = nil
  vim.api.nvim_tabpage_set_var(tab, M.BUFFER_VAR_NAME, buffers)

  -- Emit event for other plugins to react
  vim.api.nvim_exec_autocmds("User", {
    pattern = "TabscopeBufRemoved",
    data = { buf = buf, tab = tab },
  })
  return true
end

---Cleanup closed buffers from all tab buffer lists.
---Cleanup closed buffers from all tab buffer lists.
---@param buf number Buffer number to remove
local function _cleanup_handler(buf)
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local buffers = M.get(tab)
    if buffers[tostring(buf)] then
      M.remove(buf, tab)
    end
  end
end

-- Track if we're currently processing (prevents re-triggering)
local in_handler = false

---Handle buffer conflict on BufWinEnter.
---If buffer exists in another tab's list, show popup asking user what to do.
local function _conflict_handler(args)
  ---@type tabscope.bufferlist.BufInfo
  local bufinfo = { buf = args.buf, win = args.win, file = args.file }
  -- Skip if hijack is disabled in config
  if not M.config.hijack then
    return
  end

  -- Prevent re-triggering while handling
  if in_handler then
    return
  end

  -- Get the current buffer
  if not bufinfo.buf or not vim.api.nvim_buf_is_valid(bufinfo.buf) then
    return
  end

  -- Get file path - skip internal buffers (help, quickfix, etc.)
  if bufinfo.file == "" then
    return
  end

  -- Get current tab handle
  local current_tab = vim.api.nvim_get_current_tabpage()

  ---@type number?
  local target_tab = nil
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local buffers = M.get(tab)
    if buffers[tostring(bufinfo.buf)] then
      if tab == current_tab then
        return
      end
      target_tab = tab
      break
    end
  end

  -- Buffer not found elsewhere - add to current tab's list and return
  if not target_tab then
    print("Buffer not found elsewhere - add to current tab's list and return")
    M.add({ bufinfo }, current_tab)
    return
  end

  -- Buffer found in another tab - show popup
  in_handler = true

  -- Get buffer name for display
  local buf_name = vim.fn.fnamemodify(bufinfo.file, ":.")

  vim.ui.select({
    "Switch to existing tab",
    "Keep in current tab",
  }, {
    prompt = "Buffer already open in: " .. buf_name,
  }, function(choice)
    if choice == "Switch to existing tab" then
      -- Check BEFORE removal: if current tab has only the conflict buffer
      local original_buffers = M.get(current_tab)
      local should_close = false
      if dict.count(original_buffers) == 1 and original_buffers[tostring(bufinfo.buf)] then
        should_close = true
      end

      -- Remove buffer from current tab's list
      M.remove(bufinfo.buf, current_tab)

      -- Go back to previous buffer in jump list (before opening conflict file)
      vim.cmd("normal! <C-o>")

      -- Switch to target tab
      vim.defer_fn(function()
        vim.api.nvim_set_current_tabpage(target_tab)
      end, 500)

      -- Focus on the buffer in target tab
      vim.api.nvim_win_set_buf(vim.api.nvim_tabpage_get_win(target_tab), bufinfo.buf)

      -- Close current tab if it originally had only 1 buffer (the conflict)
      if should_close then
        local current_win = vim.api.nvim_tabpage_get_win(current_tab)
        vim.api.nvim_win_close(current_win, true)
      end
    else
      -- Keep in current tab - remove from other tab's list
      M.remove(bufinfo.buf, target_tab)
    end

    in_handler = false
  end)
end

---Navigate to previous buffer in tab's list.
---@param tab_handle number? Tab handle (defaults to current tab)
M.next = function(tab_handle)
  local tab = tab_handle or vim.api.nvim_get_current_tabpage()
  local win = vim.api.nvim_tabpage_get_win(tab)
  local buffers = M.get(tab)
  local buffercount = dict.count(buffers)

  if buffercount <= 1 then
    return
  end

  local current_buf = vim.api.nvim_win_get_buf(win)

  local current_info = buffers[tostring(current_buf)]
  if not current_info then
    print("current_info is nil")
    return
  end

  local current_pos = current_info.pos
  local next_pos = current_pos + 1
  if next_pos > buffercount then
    next_pos = 0
  end
  local next_buf = (function()
    for _, info in pairs(buffers) do
      if not info.pos then
        print("info.pos is nil buf buffer" .. info.buf)
      end
      if info.pos == next_pos then
        return info.buf
      end
    end
  end)()
  vim.api.nvim_win_set_buf(win, next_buf)
end

---Navigate to previous buffer in tab's list.
---@param tab_handle number? Tab handle (defaults to current tab)
M.prev = function(tab_handle)
  local tab = tab_handle or vim.api.nvim_get_current_tabpage()
  local win = vim.api.nvim_tabpage_get_win(tab)
  local buffers = M.get(tab)
  local buffercount = dict.count(buffers)

  -- Convert dictionary to sorted array by position
  if buffercount <= 1 then
    return
  end

  local current_buf = vim.api.nvim_win_get_buf(win)

  local current_info = buffers[current_buf]
  if not current_info then
    print("current_info is nil")
    return
  end

  local current_pos = current_info.pos
  local prev_pos = current_pos - 1
  if prev_pos < 1 then
    prev_pos = buffercount
  end
  local prev_buf = (function()
    for _, info in pairs(buffers) do
      if not info.pos then
        print("info.pos is nil buf buffer" .. info.buf)
      end
      if info.pos == prev_pos then
        return info.buf
      end
    end
  end)()
  vim.api.nvim_win_set_buf(win, prev_buf)
end

---Get buffer titles for picker.
---@param buffers table<string, tabscope.bufferlist.BufInfo> #Tab handle
---@return string[] Buffer #names for display
local function _get_titles(buffers)
  local titles = {}

  for buf, info in pairs(buffers) do
    local bufnr = tonumber(buf)
    if not bufnr then
      print("buf is nil")
      break
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      local name = info.file
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

  if next(buffers) == nil then
    vim.notify("No buffers in tab", vim.log.levels.INFO)
    return
  end

  -- Create sorted list for picker
  local buffer_list = {}
  for buf, info in pairs(buffers) do
    table.insert(buffer_list, { buf = buf, info = info })
  end
  table.sort(buffer_list, function(a, b)
    return a.info.pos < b.info.pos
  end)

  local titles = _get_titles(buffers)
  local picker = M.config.picker or vim.ui.select

  picker(titles, {
    prompt = "Select buffer:",
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if not choice then
      return
    end

    for i, title in ipairs(titles) do
      if title == choice then
        local win = vim.api.nvim_tabpage_get_win(tab)
        vim.api.nvim_win_set_buf(win, buffer_list[i].buf)
        -- Emit event for other plugins to react
        vim.api.nvim_exec_autocmds("User", {
          pattern = "TabscopeBufSelected",
          data = { buf = buffer_list[i].buf, tab = tab },
        })
        return
      end
    end
  end)
end

-- Setup the bufferlist module.
---@param args tabscope.bufferlist.Config?
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})

  -- Create BufWinEnter autocmd if hijack is enabled
  -- BufWinEnter fires after buffer is displayed in a window
  if M.config.hijack then
    vim.api.nvim_create_autocmd("BufWinEnter", {
      callback = _conflict_handler,
    })
  end

  -- Cleanup: remove closed buffers from all tab lists
  vim.api.nvim_create_autocmd("BufDelete", {
    callback = function(a)
      -- Note: For built-in autocmds like BufDelete, use args.buf (not args.data.buf)
      _cleanup_handler(a.buf)
    end,
  })
end

return M
