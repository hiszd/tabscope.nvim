local tablabel = require("tabscope.tablabel")

describe("tablabel", function()
  describe("LABEL_VAR_NAME", function()
    it("is a string", function()
      assert.is_string(tablabel.LABEL_VAR_NAME)
    end)

    it("is 'tabscope_tab_name'", function()
      assert.equals("tabscope_tab_name", tablabel.LABEL_VAR_NAME)
    end)
  end)

  describe("config", function()
    it("is a table", function()
      assert.is_table(tablabel.config)
    end)

    it("has enable field", function()
      assert.is_boolean(tablabel.config.enable)
    end)

    it("defaults enable to true", function()
      assert.is_true(tablabel.config.enable)
    end)
  end)

  describe("tabline", function()
    it("returns a string", function()
      assert.is_string(tablabel.tabline())
    end)

    it("returns non-empty string when no tabs", function()
      local result = tablabel.tabline()
      assert.is_true(#result > 0)
    end)

    it("returns string containing TabLine highlights", function()
      local result = tablabel.tabline()
      assert.is_true(result:match("TabLine") ~= nil)
    end)

    it("returns string containing TabLineFill", function()
      local result = tablabel.tabline()
      assert.is_true(result:match("TabLineFill") ~= nil)
    end)
  end)

  describe("setup", function()
    it("merges config", function()
      local original = tablabel.config.enable
      tablabel.setup({ enable = false })
      assert.is_false(tablabel.config.enable)
      tablabel.config.enable = original
    end)

    it("does not error with no args", function()
      assert.has_no_error(function()
        tablabel.setup()
      end)
    end)

    it("sets tabline when enabled", function()
      tablabel.setup({ enable = true })
      assert.is_string(vim.opt.tabline:get())
      assert.is_true(vim.opt.tabline:get():match("tabscope") ~= nil)
    end)
  end)

  describe("rename_tab", function()
    it("is a function", function()
      assert.is_function(tablabel.rename_tab)
    end)

    it("emits TabscopeTabRenamed event with correct data", function()
      local event_data = nil
      vim.api.nvim_create_autocmd("User", {
        pattern = "TabscopeTabRenamed",
        callback = function(args)
          event_data = args.data
        end,
      })

      vim.fn.input = function()
        return "TestTab"
      end

      tablabel.rename_tab()

      assert.is_not_nil(event_data)
      assert.is_number(event_data.tab)
      assert.equals("TestTab", event_data.name)

      vim.cmd("redrawtabline")
    end)
  end)
end)