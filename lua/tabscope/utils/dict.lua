local M = {}

---@param dict table<any, any>
M.count = function(dict)
  local count = 0
  for _, _ in pairs(dict) do
    count = count + 1
  end
  return count
end

return M
