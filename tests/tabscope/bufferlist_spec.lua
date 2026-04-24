local bufferlist = require("tabscope.bufferlist")

describe("bufferlist", function()
  local test_bufnr
  local test_file = vim.fn.tempname() .. ".lua"

  before_each(function()
    test_bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(test_bufnr, test_file)
  end)

  after_each(function()
    if test_bufnr and vim.api.nvim_buf_is_valid(test_bufnr) then
      vim.api.nvim_buf_delete(test_bufnr, { force = true })
    end
  end)

  describe("BUFFER_VAR_NAME", function()
    it("is a string", function()
      assert.is_string(bufferlist.BUFFER_VAR_NAME)
    end)

    it("is 'tabscope_buffers'", function()
      assert.equals("tabscope_buffers", bufferlist.BUFFER_VAR_NAME)
    end)
  end)

  describe("config", function()
    it("is a table", function()
      assert.is_table(bufferlist.config)
    end)

    it("has enable field", function()
      assert.is_boolean(bufferlist.config.enable)
    end)

    it("has hijack field", function()
      assert.is_boolean(bufferlist.config.hijack)
    end)

    it("has picker field", function()
      assert.is_true(bufferlist.config.picker == nil or type(bufferlist.config.picker) == "function")
    end)

    it("defaults enable to true", function()
      assert.is_true(bufferlist.config.enable)
    end)

    it("defaults hijack to true", function()
      assert.is_true(bufferlist.config.hijack)
    end)
  end)

  describe("get", function()
    it("is a function", function()
      assert.is_function(bufferlist.get)
    end)

    it("returns a table", function()
      assert.is_table(bufferlist.get())
    end)

    it("returns empty table for new tab", function()
      local tab = vim.api.nvim_get_current_tabpage()
      local result = bufferlist.get(tab)
      assert.is_table(result)
    end)

    it("returns stored buffers for tab", function()
      local tab = vim.api.nvim_get_current_tabpage()
      local test_buf = vim.api.nvim_create_buf(true, false)
      local test_file = vim.fn.tempname() .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, test_file)

      bufferlist.add({{ buf = test_buf, win = 1000, file = test_file }}, tab)

      local result = bufferlist.get(tab)
      assert.is_table(result)
      assert.is_true(result[test_file] ~= nil)

      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)
  end)

  describe("add", function()
    it("is a function", function()
      assert.is_function(bufferlist.add)
    end)

    it("adds buffer to tab's list", function()
      local tab = vim.api.nvim_get_current_tabpage()
      local test_buf = vim.api.nvim_create_buf(true, false)
      local test_file = vim.fn.tempname() .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, test_file)

      bufferlist.add({{ buf = test_buf, win = 1000, file = test_file }}, tab)

      local result = bufferlist.get(tab)
      assert.is_true(result[test_file] ~= nil)
      assert.equals(test_buf, result[test_file].buf)

      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)

    it("assigns position to buffer", function()
      local tab = vim.api.nvim_get_current_tabpage()
      local test_buf = vim.api.nvim_create_buf(true, false)
      local test_file = vim.fn.tempname() .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, test_file)

      bufferlist.add({{ buf = test_buf, win = 1000, file = test_file }}, tab)

      local result = bufferlist.get(tab)
      assert.is_number(result[test_file].pos)
      assert.is_true(result[test_file].pos > 0)

      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)

    it("increments position for multiple buffers", function()
      local tab = vim.api.nvim_get_current_tabpage()

      local test_buf1 = vim.api.nvim_create_buf(true, false)
      local test_file1 = vim.fn.tempname() .. ".lua"
      vim.api.nvim_buf_set_name(test_buf1, test_file1)

      local test_buf2 = vim.api.nvim_create_buf(true, false)
      local test_file2 = vim.fn.tempname() .. ".lua"
      vim.api.nvim_buf_set_name(test_buf2, test_file2)

      bufferlist.add({
        { buf = test_buf1, win = 1000, file = test_file1 },
        { buf = test_buf2, win = 1001, file = test_file2 },
      }, tab)

      local result = bufferlist.get(tab)
      assert.is_number(result[test_file1].pos)
      assert.is_number(result[test_file2].pos)
      assert.is_true(result[test_file1].pos < result[test_file2].pos, "first buffer should have lower position than second")

      vim.api.nvim_buf_delete(test_buf1, { force = true })
      vim.api.nvim_buf_delete(test_buf2, { force = true })
    end)

    it("emits TabscopeBufAdded event", function()
      local tab = vim.api.nvim_get_current_tabpage()
      local test_buf = vim.api.nvim_create_buf(true, false)
      local test_file = vim.fn.tempname() .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, test_file)

      local event_fired = false
      vim.api.nvim_create_autocmd("User", {
        pattern = "TabscopeBufAdded",
        callback = function() event_fired = true end,
      })

      bufferlist.add({{ buf = test_buf, win = 1000, file = test_file }}, tab)

      assert.is_true(event_fired)

      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)
  end)

  describe("remove", function()
    it("is a function", function()
      assert.is_function(bufferlist.remove)
    end)

    it("removes buffer from tab's list", function()
      local tab = vim.api.nvim_get_current_tabpage()
      local test_buf = vim.api.nvim_create_buf(true, false)
      local test_file = vim.fn.tempname() .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, test_file)

      bufferlist.add({{ buf = test_buf, win = 1000, file = test_file }}, tab)

      local before = bufferlist.get(tab)
      assert.is_true(before[test_file] ~= nil)

      bufferlist.remove({ test_file }, tab)

      local after = bufferlist.get(tab)
      assert.is_nil(after[test_file])

      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)

    it("emits TabscopeBufRemoved event", function()
      local tab = vim.api.nvim_get_current_tabpage()
      local test_buf = vim.api.nvim_create_buf(true, false)
      local test_file = vim.fn.tempname() .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, test_file)

      bufferlist.add({{ buf = test_buf, win = 1000, file = test_file }}, tab)

      local event_fired = false
      vim.api.nvim_create_autocmd("User", {
        pattern = "TabscopeBufRemoved",
        callback = function() event_fired = true end,
      })

      bufferlist.remove({ test_file }, tab)

      assert.is_true(event_fired)

      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)

    it("handles non-existent file gracefully", function()
      local tab = vim.api.nvim_get_current_tabpage()

      assert.has_no_error(function()
        bufferlist.remove({ "non_existent_file.lua" }, tab)
      end)
    end)
  end)

  describe("restore", function()
    it("is a function", function()
      assert.is_function(bufferlist.restore)
    end)

    it("restores buffer to tab", function()
      local tab = vim.api.nvim_get_current_tabpage()
      local test_buf = vim.api.nvim_create_buf(true, false)
      local test_file = vim.fn.tempname() .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, test_file)

      local session_data = {
        { buf = test_buf, win = 1000, file = test_file, pos = 1 },
      }

      bufferlist.restore(session_data, tab)

      local result = bufferlist.get(tab)
      assert.is_true(result[test_file] ~= nil)

      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)

    it("emits TabscopeBufRestored event", function()
      local tab = vim.api.nvim_get_current_tabpage()
      local test_buf = vim.api.nvim_create_buf(true, false)
      local test_file = vim.fn.tempname() .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, test_file)

      local session_data = {
        { buf = test_buf, win = 1000, file = test_file, pos = 1 },
      }

      local event_fired = false
      vim.api.nvim_create_autocmd("User", {
        pattern = "TabscopeBufRestored",
        callback = function() event_fired = true end,
      })

      bufferlist.restore(session_data, tab)

      assert.is_true(event_fired)

      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)
  end)

  describe("next", function()
    it("is a function", function()
      assert.is_function(bufferlist.next)
    end)

    it("does not error on empty buffer list", function()
      local tab = vim.api.nvim_get_current_tabpage()

      assert.has_no_error(function()
        bufferlist.next(tab)
      end)
    end)

    it("does not error on single buffer", function()
      local tab = vim.api.nvim_get_current_tabpage()
      local test_buf = vim.api.nvim_create_buf(true, false)
      local test_file = vim.fn.tempname() .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, test_file)

      bufferlist.add({{ buf = test_buf, win = 1000, file = test_file }}, tab)

      assert.has_no_error(function()
        bufferlist.next(tab)
      end)

      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)
  end)

  describe("prev", function()
    it("is a function", function()
      assert.is_function(bufferlist.prev)
    end)

    it("does not error on empty buffer list", function()
      local tab = vim.api.nvim_get_current_tabpage()

      assert.has_no_error(function()
        bufferlist.prev(tab)
      end)
    end)

    it("does not error on single buffer", function()
      local tab = vim.api.nvim_get_current_tabpage()
      local test_buf = vim.api.nvim_create_buf(true, false)
      local test_file = vim.fn.tempname() .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, test_file)

      bufferlist.add({{ buf = test_buf, win = 1000, file = test_file }}, tab)

      assert.has_no_error(function()
        bufferlist.prev(tab)
      end)

      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)
  end)

  describe("list", function()
    it("is a function", function()
      assert.is_function(bufferlist.list)
    end)

    it("notifies on empty buffer list", function()
      local tab = vim.api.nvim_get_current_tabpage()

      local notified = false
      vim.notify = function(msg)
        notified = true
      end

      bufferlist.list(tab)

      assert.is_true(notified)

      vim.notify = nil
    end)

    it("calls picker with buffer titles", function()
      local tab = vim.api.nvim_get_current_tabpage()
      local test_buf = vim.api.nvim_create_buf(true, false)
      local test_file = vim.fn.tempname() .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, test_file)

      bufferlist.add({{ buf = test_buf, win = 1000, file = test_file }}, tab)

      local picker_called = false
      local titles_received = {}
      bufferlist.config.picker = function(titles, opts, callback)
        picker_called = true
        titles_received = titles
        callback(nil)
      end

      bufferlist.list(tab)

      assert.is_true(picker_called)
      assert.is_true(#titles_received > 0)

      bufferlist.config.picker = nil
      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)
  end)

  describe("setup", function()
    it("merges config", function()
      local original = bufferlist.config.hijack
      bufferlist.setup({ hijack = false })
      assert.is_false(bufferlist.config.hijack)
      bufferlist.config.hijack = original
    end)

    it("does not error with no args", function()
      assert.has_no_error(function()
        bufferlist.setup()
      end)
    end)
  end)
end)