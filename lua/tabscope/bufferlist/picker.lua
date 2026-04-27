---Picker module for tabscope.bufferlist.
---Handles directory/file listing and picker integration.
---@class tabscope.bufferlist.picker.Module
local M = {}

---Path separator for concatenation.
local function join_path(base, name)
  return base .. "/" .. name
end

---Find common parent directory from a list of directories.
---Returns the common prefix, or nil if no meaningful common parent.
---@param paths string[] # List of directory paths
---@return number, string? # Common parent directory
local find_common_parent = function(paths)
  if #paths == 0 then
    return 0, nil
  end
  if #paths == 1 then
    return 0, paths[1]
  end
  ---@type number
  local common_parts = vim.iter(paths):fold(9999, function(acc, path)
    print("path: ", path)
    ---@cast path string
    local parts = vim.split(path, "/")
    if path:find("/") == 1 then
      table.remove(parts, 1)
    end
    local common = vim.iter(paths):fold(9999, function(ac, p)
      if path == p then
        return ac
      end
      local pts = vim.split(p, "/")
      if p:find("/") == 1 then
        table.remove(pts, 1)
      end
      -- NOTE: for each part that matches the other string we add 1
      local w = vim.iter(pts):enumerate():fold(0, function(a, i, pt)
        if pt == parts[i] then
          return a + 1
        end
        return a
      end)
      if w < ac then
        return w
      end
      return ac
    end)
    if common < acc then
      return common
    end
    return acc
  end)

  local common_string = (function()
    if common_parts == 9999 then
      return nil
    end
    local parts = vim.split(paths[1], "/")
    return vim.iter(parts):enumerate():fold("", function(acc, i, part)
      if i <= common_parts + 1 then
        return acc .. part .. "/"
      end
      return acc
    end)
  end)()

  return common_parts, common_string
end

---Get directories to search based on scope.
---@param scope string "tab" or "global"
---@return string[] List of unique directories to search
function M.get_search_directories(scope)
  local dirs = {}

  if scope == "global" then
    -- Add global cwd first
    local global_cwd = vim.fn.getcwd(-1, -1)
    if global_cwd and global_cwd ~= "" then
      dirs[global_cwd] = true
    end

    -- Add each tab's cwd
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
      local tab_cwd = vim.fn.getcwd(0, tab)
      if tab_cwd and tab_cwd ~= "" then
        dirs[tab_cwd] = true
      end
    end
  else
    -- tab scope: use current tab's cwd (or global fallback)
    local tab = vim.api.nvim_get_current_tabpage()
    local cwd = vim.fn.getcwd(0, tab)
    if not cwd or cwd == "" then
      cwd = vim.fn.getcwd(-1, -1)
    end
    if cwd and cwd ~= "" then
      dirs[cwd] = true
    end
  end

  -- Convert to array
  local result = {}
  for dir, _ in pairs(dirs) do
    table.insert(result, dir)
  end
  return result
end

---List subdirectories from multiple roots.
---@param directories string[] List of root directories to search
---@param max_depth number Maximum depth to search
---@return { path: string, search_dir: string }[] List of directories with metadata
function M.list_directories(directories, max_depth)
  ---@type { path: string, search_dir: string }[]
  local found_dirs = {}
  max_depth = max_depth or 10

  local _, common = find_common_parent(directories)

  if not common then
    return found_dirs
  end

  for _, root_path in ipairs(directories) do
    local function search(path, depth)
      if depth > max_depth then
        return
      end

      local success, entries = pcall(vim.fn.readdir, path)
      if not success then
        return
      end

      for _, name in ipairs(entries) do
        local full_path = join_path(path, name)

        if vim.fn.isdirectory(full_path) == 1 then
          -- Make relative to the search directory (not common parent for single dir)
          local rel_path
          if string.find(full_path, common, 1, true) then
            rel_path = string.sub(full_path, #common + 1)
          else
            rel_path = full_path
          end

          table.insert(found_dirs, {
            path = rel_path,
            search_dir = root_path,
          })
          search(full_path, depth + 1)
        end
      end
    end

    search(root_path, 1)
  end

  return found_dirs
end

---List all files from multiple roots.
---@param directories string[] List of root directories to search
---@param max_depth number Maximum depth to search
---@return { path: string, search_dir: string }[] List of files with metadata
function M.list_files(directories, max_depth)
  local found_files = {}
  max_depth = max_depth or 10

  local _, common = find_common_parent(directories)
  if not common then
    return found_files
  end

  for _, root_path in ipairs(directories) do
    local function search(path, depth)
      if depth > max_depth then
        return
      end

      local success, entries = pcall(vim.fn.readdir, path)
      if not success then
        return
      end

      for _, name in ipairs(entries) do
        local full_path = join_path(path, name)

        if vim.fn.isdirectory(full_path) == 1 then
          -- Recurse into subdirectory, don't add to files list
          search(full_path, depth + 1)
        else
          -- Make relative to the search directory (not common parent for single dir)
          local rel_path
          if string.find(full_path, common, 1, true) then
            rel_path = string.sub(full_path, #common + 1)
          else
            rel_path = full_path
          end

          table.insert(found_files, {
            path = rel_path,
            search_dir = root_path,
          })
        end
      end
    end

    search(root_path, 1)
  end

  return found_files
end

---Check if snacks picker is available.
---@return boolean
function M.has_snacks()
  local ok, snacks = pcall(require, "snacks.picker")
  if not ok or not snacks then
    return false
  end
  -- Check if the picker API functions exist
  return type(snacks.pick) == "function" or type(snacks.files) == "function" or type(snacks.picker) == "function"
end

---Check if telescope is available.
---@return boolean
function M.has_telescope()
  local ok, mod = pcall(require, "telescope.pickers")
  return ok and mod ~= nil
end

---Get the best available picker backend.
---Priority: snacks > telescope > vim.ui.select
---@return "snacks" | "telescope" | "vim_ui"
function M.get_picker_backend()
  if M.has_snacks() then
    return "snacks"
  elseif M.has_telescope() then
    return "telescope"
  end
  return "vim_ui"
end

---Pick using vim.ui.select.
---@param items string[]
---@param opts table? Options (prompt, on_select)
function M.pick_with_vim_ui(items, opts)
  opts = opts or {}
  vim.ui.select(items, {
    prompt = opts.title or "Select",
  }, function(choice)
    if choice and opts.on_select then
      opts.on_select(choice)
    end
  end)
end

---Pick using snacks picker.
---@param items string[]
---@param opts table? Options (prompt, title, on_select)
function M.pick_with_snacks(items, opts)
  opts = opts or {}

  local ok, Snacks = pcall(require, "snacks.picker")
  if not ok or not Snacks then
    -- Fallback to vim.ui.select if snacks failed to load
    M.pick_with_vim_ui(items, opts)
    return
  end

  local items_with_text = vim
    .iter(items)
    :map(function(item)
      return { text = item }
    end)
    :totable()

  local picker_opts = {
    title = opts.title or "Select",
    source = "custom",
    finder = {
      items = items_with_text,
    },
  }

  local fn = Snacks.pick or Snacks.picker
  if type(fn) == "function" then
    local success, err = pcall(fn, Snacks, picker_opts, function(picker, selected)
      if selected and selected[1] then
        local choice = selected[1].text
        if picker and picker.close then
          picker:close()
        end
        if opts.on_select then
          opts.on_select(choice)
        end
      end
    end)
    if not success then
      -- Fallback to vim.ui.select if snacks call failed
      M.pick_with_vim_ui(items, opts)
    end
  else
    -- Fallback to vim.ui.select if no picker function exists
    M.pick_with_vim_ui(items, opts)
  end
end

---Generic pick function that uses the best available picker.
---@param items string[]
---@param opts table? Options (prompt, title, query, on_select)
function M.pick(items, opts)
  opts = opts or {}
  local backend = M.get_picker_backend()

  if backend == "snacks" then
    M.pick_with_snacks(items, opts)
  else
    -- Fallback to vim.ui.select for telescope or vim_ui
    M.pick_with_vim_ui(items, opts)
  end
end

---Export find_common_parent for use in bufferlist
M.find_common_parent = find_common_parent

return M
