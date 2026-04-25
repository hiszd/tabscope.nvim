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

      bufferlist.add({{ file = test_file }}, tab)

      local result = bufferlist.get(tab)
      assert.is_true(result[test_file] ~= nil)

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

    it("emits TabscopeBufAdded event with correct data", function()
      local tab = vim.api.nvim_get_current_tabpage()
      local test_buf = vim.api.nvim_create_buf(true, false)
      local test_file = vim.fn.tempname() .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, test_file)

      local event_data = nil
      vim.api.nvim_create_autocmd("User", {
        pattern = "TabscopeBufAdded",
        callback = function(args)
          event_data = args.data
        end,
      })

      bufferlist.add({{ file = test_file }}, tab)

      assert.is_not_nil(event_data)
      assert.is_number(event_data.tab)
      assert.is_table(event_data.bufs)

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

    it("emits TabscopeBufRemoved event with correct data", function()
      local tab = vim.api.nvim_get_current_tabpage()
      local test_buf = vim.api.nvim_create_buf(true, false)
      local test_file = vim.fn.tempname() .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, test_file)

      bufferlist.add({{ file = test_file }}, tab)

      local event_data = nil
      vim.api.nvim_create_autocmd("User", {
        pattern = "TabscopeBufRemoved",
        callback = function(args)
          event_data = args.data
        end,
      })

      bufferlist.remove({ test_file }, tab)

      assert.is_not_nil(event_data)
      assert.is_number(event_data.tab)
      assert.is_table(event_data.files)

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

    it("emits TabscopeBufRestored event with correct data", function()
      local tab = vim.api.nvim_get_current_tabpage()
      local test_buf = vim.api.nvim_create_buf(true, false)
      local test_file = vim.fn.tempname() .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, test_file)

      local session_data = {
        { file = test_file, pos = 1 },
      }

      local event_data = nil
      vim.api.nvim_create_autocmd("User", {
        pattern = "TabscopeBufRestored",
        callback = function(args)
          event_data = args.data
        end,
      })

      bufferlist.restore(session_data, tab)

      assert.is_not_nil(event_data)
      assert.is_number(event_data.tab)
      assert.is_table(event_data.bufs)

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
      bufferlist._state[tostring(tab)] = {}

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

      bufferlist.add({{ file = test_file }}, tab)

      local picker_called = false
      bufferlist.config.picker = function(titles, opts, callback)
        picker_called = true
        callback(titles[1])
      end

      bufferlist.list(tab)

      assert.is_true(picker_called)

      bufferlist.config.picker = nil
      vim.api.nvim_buf_delete(test_buf, { force = true })
    end)

    it("emits TabscopeBufSelected event with correct data", function()
      local tab = vim.api.nvim_get_current_tabpage()
      local test_buf = vim.api.nvim_create_buf(true, false)
      local test_file = vim.fn.tempname() .. ".lua"
      vim.api.nvim_buf_set_name(test_buf, test_file)

      bufferlist.add({{ file = test_file }}, tab)

      local event_data = nil
      vim.api.nvim_create_autocmd("User", {
        pattern = "TabscopeBufSelected",
        callback = function(args)
          event_data = args.data
        end,
      })

      bufferlist.config.picker = function(titles, opts, callback)
        callback(titles[1])
      end

      bufferlist.list(tab)

      assert.is_not_nil(event_data)
      assert.is_number(event_data.tab)
      assert.is_number(event_data.buf)

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

  describe("BufInfo", function()
    local BufInfo

    before_each(function()
      BufInfo = require("tabscope.bufferlist.bufinfo")
    end)

    describe("new", function()
      it("creates instance with file and pos fields", function()
        local info = BufInfo.new({ file = "test.lua", pos = 1 })
        assert.is_table(info)
        assert.equals("test.lua", info.file)
        assert.equals(1, info.pos)
      end)

      it("handles missing pos gracefully", function()
        local info = BufInfo.new({ file = "test.lua" })
        assert.is_table(info)
        assert.equals("test.lua", info.file)
        assert.is_nil(info.pos)
      end)
    end)

    describe("from_buffer", function()
      it("creates instance from valid buffer", function()
        local buf = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(buf, "/tmp/test.lua")
        local info = BufInfo.from_buffer(buf)
        assert.is_table(info)
        assert.equals("/tmp/test.lua", info.file)
        vim.api.nvim_buf_delete(buf, { force = true })
      end)

      it("returns nil for invalid buffer", function()
        local info = BufInfo.from_buffer(99999)
        assert.is_nil(info)
      end)
    end)

    describe("get_display_name", function()
      it("returns filename or relative path for valid path", function()
        local info = BufInfo.new({ file = "/tmp/test.lua" })
        local name = info:get_display_name()
        assert.is_string(name)
        assert.is_true(name == "test.lua" or name == "/tmp/test.lua")
      end)

      it("returns [No Name] for empty file", function()
        local info = BufInfo.new({ file = "" })
        assert.equals("[No Name]", info:get_display_name())
      end)
    end)

    describe("get_buffer", function()
      it("returns buffer number for valid file", function()
        local buf = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(buf, "/tmp/test.lua")
        local info = BufInfo.new({ file = "/tmp/test.lua" })
        local bufnr = info:get_buffer()
        assert.equals(buf, bufnr)
        vim.api.nvim_buf_delete(buf, { force = true })
      end)
    end)

    describe("is_valid", function()
      it("returns true for valid buffer", function()
        local buf = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(buf, "/tmp/test.lua")
        local info = BufInfo.new({ file = "/tmp/test.lua" })
        assert.is_true(info:is_valid())
        vim.api.nvim_buf_delete(buf, { force = true })
      end)

      it("returns false for invalid buffer", function()
        local info = BufInfo.new({ file = "/tmp/nonexistent.lua" })
        assert.is_false(info:is_valid())
      end)
    end)

    describe("set_position", function()
      it("sets the position field", function()
        local info = BufInfo.new({ file = "test.lua" })
        assert.is_nil(info.pos)
        info:set_position(5)
        assert.equals(5, info.pos)
      end)
    end)

    describe("to_table", function()
      it("returns plain table with file and pos", function()
        local info = BufInfo.new({ file = "test.lua", pos = 3 })
        local tbl = info:to_table()
        assert.is_table(tbl)
        assert.equals("test.lua", tbl.file)
        assert.equals(3, tbl.pos)
      end)
    end)
  end)
end)