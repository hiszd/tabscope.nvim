-- Each of these modules has it's own functionality that can be used seperately to curate the scope that you want to manage within your tabs
local label = require("tabscope.tablabel")
local bufferlist = require("tabscope.bufferlist")

---@class tabscope.Config
---@field tablabel tabscope.tablabel.Config? The tab label configuration
---@field bufferlist tabscope.bufferlist.Config? The buffer list configuration
local config = {
  tablabel = label.config,
  bufferlist = bufferlist.config,
}

---@class tabscope.Module
local M = {}

---@type tabscope.Config
M.config = config

---@param args tabscope.Config?
-- you can define your setup function here. Usually configurations can be merged, accepting outside params and
-- you can also put some validation here for those.
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
  if M.config.tablabel.enable then
    require("tabscope.tablabel").setup(M.config.tablabel)
  end
  if M.config.bufferlist.enable then
    require("tabscope.bufferlist").setup(M.config.bufferlist)
  end
end

return M
