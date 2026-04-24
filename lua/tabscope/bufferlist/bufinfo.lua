---BufInfo class with metatable methods for buffer data.
---@class tabscope.bufferlist.BufInfo
---@field file string File path
---@field pos number? Position in buffer list
local BufInfo = {}
BufInfo.__index = BufInfo

---Create a new BufInfo instance.
---@param opts { file: string, pos: number }
---@return tabscope.bufferlist.BufInfo
function BufInfo.new(opts)
  local self = setmetatable({}, BufInfo)
  self.file = opts.file
  self.pos = opts.pos
  return self
end

---Create BufInfo from buffer number.
---@param bufnr number
---@param pos number?
---@return tabscope.bufferlist.BufInfo?
function BufInfo.from_buffer(bufnr, pos)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end
  return BufInfo.new({
    file = vim.api.nvim_buf_get_name(bufnr),
    pos = pos or 0,
  })
end

---Check if the buffer is valid.
---@return boolean
function BufInfo:is_valid()
  local buf = vim.fn.bufnr(self.file)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

---Get a display-friendly name.
---@return string
function BufInfo:get_display_name()
  if not self.file or self.file == "" then
    return "[No Name]"
  end
  return vim.fn.fnamemodify(self.file, ":.")
end

---Update position in list.
---@param pos number
function BufInfo:set_position(pos)
  self.pos = pos
end

---Get buffer number.
---@return number
function BufInfo:get_buffer()
  return vim.fn.bufnr(self.file)
end

---Convert to plain table for serialization.
---@return { buf: number, win: number, file: string, pos: number? }
function BufInfo:to_table()
  return {
    file = self.file,
    pos = self.pos,
  }
end

return BufInfo

