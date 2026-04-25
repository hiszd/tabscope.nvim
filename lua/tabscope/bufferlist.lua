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

local BufInfo = require("tabscope.bufferlist.bufinfo")
local dict = require("tabscope.utils.dict")

---Buffer list variable name (for resession backup).
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

---Module state: tab_handle -> dictionary of filename -> BufInfo
---Stores metatable objects for full API access in-memory.
M._state = {}

---Sync _state to tabpage variable (for resession backup).
---@param tab string
local function _sync_to_tabpage(tab)
  local buffers = M._state[tab]
  if not buffers then
    return
  end
  local t = tonumber(tab)
  if not t then
    return
  end

  vim.api.nvim_tabpage_set_var(t, M.BUFFER_VAR_NAME, buffers)
end

---Set buffers directly in state and sync to tabpage.
---@param tab string
---@param buffers table<string, tabscope.bufferlist.BufInfo>
local function _set_in_state(tab, buffers)
  M._state[tab] = buffers
  _sync_to_tabpage(tab)
end

---Get buffer list for a tab.
---Returns a dictionary with file paths as keys and BufInfo as values.
---@param tab_handle number? # Tab handle (defaults to current tab)
---@return table<string, tabscope.bufferlist.BufInfo> # Dictionary of BufInfo keyed by filename
M.get = function(tab_handle)
  local tab = tab_handle or vim.api.nvim_get_current_tabpage()
  return M._state[tostring(tab)] or {}
end

---Restore buffer from session manager.
---Accepts plain table data from resession and creates BufInfo objects.
---@param bufinfo table[] Buffer info from session (plain tables)
---@param tab_handle number? Tab handle (defaults to current tab)
M.restore = function(bufinfo, tab_handle)
  local tab = tab_handle or vim.api.nvim_get_current_tabpage()
  local added = {}
  if not bufinfo then
    return
  end

  local buffers = {}
  local position = 1
  vim.iter(bufinfo):each(function(info)
    ---@cast info {file: string, pos: number} | nil
    if not info or not info.file then
      return
    end

    local new_bufnr = vim.fn.bufnr(info.file)
    if vim.api.nvim_buf_is_valid(new_bufnr) then
      local bufin = BufInfo.new(info)
      bufin:set_position(position)
      position = position + 1
      buffers[info.file] = bufin
      table.insert(added, bufin)
    end
  end)

  _set_in_state(tostring(tab), buffers)

  vim.api.nvim_exec_autocmds("User", {
    pattern = "TabscopeBufRestored",
    data = { tab = tab, bufs = added },
  })
end

---Add buffer to tab's buffer list.
---@param bufinfo tabscope.bufferlist.BufInfo[] Buffer info to add
---@param tab_handle number? Tab handle (defaults to current tab)
M.add = function(bufinfo, tab_handle)
  local tab = tab_handle or vim.api.nvim_get_current_tabpage()
  local buffers = M.get(tab)

  local position = dict.count(buffers) + 1

  vim.iter(bufinfo):each(function(info)
    ---@cast info tabscope.bufferlist.BufInfo
    local bufin
    if type(info) == "table" then
      if info.is_valid and info.get_display_name then
        bufin = info
      else
        bufin = BufInfo.new(info)
      end
    end

    if not bufin or not bufin.file then
      return
    end

    bufin:set_position(position)
    position = position + 1
    buffers[bufin.file] = bufin
  end)

  _set_in_state(tostring(tab), buffers)

  vim.api.nvim_exec_autocmds("User", {
    pattern = "TabscopeBufAdded",
    data = { tab = tab, bufs = bufinfo },
  })
end

---Remove buffer from tab's buffer list.
---@param files string[] Filenames to remove
---@param tab_handle number? Tab handle (defaults to current tab)
---@return boolean
M.remove = function(files, tab_handle)
  local tab = tab_handle or vim.api.nvim_get_current_tabpage()
  local buffers = M.get(tab)

  vim.iter(files):each(function(file)
    ---@cast file string
    buffers[file] = nil
    buffers = vim.iter(buffers):enumerate():fold({}, function(acc, i, _, info)
      ---@cast info tabscope.bufferlist.BufInfo
      info:set_position(i)
      acc[info.file] = info
      return acc
    end)
  end)

  _set_in_state(tostring(tab), buffers)

  vim.api.nvim_exec_autocmds("User", {
    pattern = "TabscopeBufRemoved",
    data = { tab = tab, files = files },
  })
  return dict.count(buffers) == 0
end

---Cleanup closed buffers from all tab buffer lists.
---@param buf number Buffer number to remove
local function _cleanup_handler(buf)
  vim.iter(vim.api.nvim_list_tabpages()):each(function(tab)
    ---@cast tab integer
    local buffers = M.get(tab)
    vim.iter(buffers):any(function(_, info)
      ---@cast info tabscope.bufferlist.BufInfo
      if info:get_buffer() == buf then
        M.remove({ info.file }, tab)
        return true
      end
      return false
    end)
  end)
end

---Track if we're currently processing (prevents re-triggering).
local in_handler = false

---Handle buffer conflict on BufWinEnter.
---If buffer exists in another tab's list, show popup asking user what to do.
local function _conflict_handler(args)
  local win = vim.api.nvim_get_current_win()
  local bufinfo = BufInfo.from_buffer(args.buf)
  if not bufinfo then
    return
  end

  if not M.config.hijack then
    return
  end

  if in_handler then
    return
  end

  if bufinfo.file == "" then
    return
  end

  local current_tab = vim.api.nvim_get_current_tabpage()

  local target_tab = nil
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local buffers = M.get(tab)
    if buffers[bufinfo.file] then
      if tab == current_tab then
        return
      end
      target_tab = tab
      break
    end
  end

  if not target_tab then
    M.add({ bufinfo }, current_tab)
    return
  end

  local tabwins = vim
    .iter(vim.api.nvim_list_tabpages())
    :map(function(t)
      return vim.api.nvim_tabpage_get_win(t)
    end)
    :totable()
  if not vim.iter(tabwins):find(function(w)
    return w == win
  end) then
    return
  end

  in_handler = true

  local buf_name = bufinfo:get_display_name()

  vim.ui.select({
    "Switch to existing tab",
    "Keep in current tab",
  }, {
    prompt = "Buffer already open: " .. buf_name,
  }, function(choice)
    if choice == "Switch to existing tab" then
      local original_buffers = M.get(current_tab)
      local should_close = false
      if dict.count(original_buffers) == 1 and original_buffers[bufinfo.file] then
        should_close = true
      end

      M.remove({ bufinfo.file }, current_tab)

      vim.api.nvim_win_call(win, function()
        vim.cmd("b#")
      end)

      vim.api.nvim_set_current_tabpage(target_tab)

      vim.api.nvim_win_set_buf(vim.api.nvim_tabpage_get_win(target_tab), bufinfo:get_buffer())
      if should_close then
        local current_win = vim.api.nvim_tabpage_get_win(current_tab)
        vim.api.nvim_win_close(current_win, true)
      end
    else
      local cur_buf = vim.api.nvim_win_get_buf(vim.api.nvim_tabpage_get_win(target_tab))
      local bufs = M.get(target_tab)
      local should_close = false
      if dict.count(bufs) <= 1 then
        should_close = true
      end
      if should_close then
        if M.remove({ bufinfo.file }, target_tab) then
          vim.cmd("tabclose " .. target_tab)
        end
      elseif not should_close and cur_buf == bufinfo:get_buffer() then
        M.prev(target_tab)
        M.remove({ bufinfo.file }, target_tab)
      else
        M.remove({ bufinfo.file }, target_tab)
      end
      M.add({ bufinfo }, current_tab)
    end

    in_handler = false
  end)
end

---Navigate to next buffer in tab's list.
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
  local current_file = vim.api.nvim_buf_get_name(current_buf)

  local current_info = buffers[current_file]
  if not current_info then
    return
  end

  local current_pos = current_info.pos
  local next_pos = current_pos + 1
  if next_pos > buffercount then
    next_pos = 1
  end

  local _, next_info = vim.iter(buffers):find(function(_, info)
    ---@cast info tabscope.bufferlist.BufInfo
    return info.pos == next_pos
  end)
  if not next_info then
    return
  end
  vim.api.nvim_win_set_buf(win, next_info:get_buffer())
end

---Navigate to previous buffer in tab's list.
---@param tab_handle number? Tab handle (defaults to current tab)
M.prev = function(tab_handle)
  local tab = tab_handle or vim.api.nvim_get_current_tabpage()
  local win = vim.api.nvim_tabpage_get_win(tab)
  local buffers = M.get(tab)
  local buffercount = dict.count(buffers)

  if buffercount <= 1 then
    return
  end

  local current_buf = vim.api.nvim_win_get_buf(win)
  local current_file = vim.api.nvim_buf_get_name(current_buf)

  local current_info = buffers[current_file]
  if not current_info then
    return
  end

  local current_pos = current_info.pos
  local prev_pos = current_pos - 1
  if prev_pos < 1 then
    prev_pos = buffercount
  end

  local _, prev_info = vim.iter(buffers):find(function(_, info)
    ---@cast info tabscope.bufferlist.BufInfo
    return info.pos == prev_pos
  end)
  if not prev_info then
    return
  end
  vim.api.nvim_win_set_buf(win, prev_info:get_buffer())
end

---Get buffer titles for picker.
---@param buffers table<string, tabscope.bufferlist.BufInfo>
---@return string[]
local function _get_titles(buffers)
  return vim
    .iter(buffers)
    :map(function(_, info)
      return info:get_display_name()
    end)
    :totable()
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

  ---@type tabscope.bufferlist.BufInfo[]
  local buffer_list = vim.iter(buffers):fold({}, function(acc, _, info)
    ---@cast info tabscope.bufferlist.BufInfo
    table.insert(acc, info)
    return acc
  end)

  local picker = M.config.picker or vim.ui.select

  picker(buffer_list, {
    prompt = "Select buffer:",
    format_item = function(info)
      ---@cast info tabscope.bufferlist.BufInfo
      return info:get_display_name()
    end,
  }, function(choice)
    ---@cast choice tabscope.bufferlist.BufInfo | nil
    if not choice then
      return
    end

    local win = vim.api.nvim_tabpage_get_win(tab)
    local buf = choice:get_buffer()
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_exec_autocmds("User", {
      pattern = "TabscopeBufSelected",
      data = { tab = tab, buf = buf },
    })
  end)
end

---Initialize _state from existing tabpage variables.
---Called on setup to load existing buffers into memory.
local function _load_from_tabpage()
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local success, stored = pcall(vim.api.nvim_tabpage_get_var, tab, M.BUFFER_VAR_NAME)
    if success and type(stored) == "table" and next(stored) then
      local buffers = {}
      local position = 1

      vim.iter(stored):each(function(_, info)
        ---@cast info {file: string, pos: number}
        local bufinfo = BufInfo.new(info)
        bufinfo:set_position(position)
        position = position + 1
        buffers[info.file] = bufinfo
      end)

      M._state[tab] = buffers
      _sync_to_tabpage(tostring(tab))
    end
  end
end

---Setup the bufferlist module.
---@param args tabscope.bufferlist.Config?
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})

  _load_from_tabpage()

  if M.config.hijack then
    vim.api.nvim_create_autocmd("BufWinEnter", {
      callback = _conflict_handler,
    })
  end

  vim.api.nvim_create_autocmd("BufDelete", {
    callback = function(a)
      _cleanup_handler(a.buf)
    end,
  })
end

return M
