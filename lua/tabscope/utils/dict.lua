local M = {}

---@param dict table<any, any>
M.count = function(dict)
  return vim.iter(dict):fold(0, function(acc, _)
    return acc + 1
  end)
end

return M
