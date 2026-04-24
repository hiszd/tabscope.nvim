local buf = vim.fn.bufnr("/home/zion/programming/nvim/tabscope.nvim/README.md")
local win = vim.fn.bufwinid(buf)
print(vim.inspect({ buf = buf, win = win }))
