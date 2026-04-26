---Picker module for tabscope.bufferlist.
---Handles directory/file listing and picker integration.
---@class tabscope.bufferlist.picker.Module
local M = {}

---Path separator for concatenation.
local function join_path(base, name)
  return base .. "/" .. name
end

---Find common parent directory from a list of directories.
---Returns the common prefix, or nil if no common parent.
---@param dirs string[] List of directory paths
---@return string? Common parent directory
local function find_common_parent(dirs)
  if #dirs == 0 then
    return nil
  end

  local first = dirs[1]
  local first_parts = vim.split(first, "/", { plain = true })

  -- Check each part against all directories
  local common_parts = {}
  for i = 1, #first_parts do
    local part = first_parts[i]
    local all_match = true

    for j = 2, #dirs do
      local other_parts = vim.split(dirs[j], "/", { plain = true })
      if not other_parts[i] or other_parts[i] ~= part then
        all_match = false
        break
      end
    end

    if all_match then
      table.insert(common_parts, part)
    else
      break
    end
  end

  if #common_parts == 0 then
    return nil
  end

  return "/" .. table.concat(common_parts, "/")
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
  local found_dirs = {}
  max_depth = max_depth or 10

  -- Find common parent of search directories
  local common = find_common_parent(directories)

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
          -- Make relative to common parent
          local rel_path
          if common then
            local prefix = common .. "/"
            if string.find(full_path, prefix, 1, true) then
              rel_path = string.sub(full_path, #prefix + 1)
            else
              rel_path = full_path
            end
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

  -- Find common parent of search directories
  local common = find_common_parent(directories)

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
          -- Make relative to common parent
          local rel_path
          if common then
            local prefix = common .. "/"
            if string.find(full_path, prefix, 1, true) then
              rel_path = string.sub(full_path, #prefix + 1)
            else
              rel_path = full_path
            end
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

  local items_with_text = vim.iter(items):map(function(item)
    return { text = item }
  end):totable()

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

return M

