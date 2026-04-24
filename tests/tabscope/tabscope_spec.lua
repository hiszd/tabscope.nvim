local tabscope = require("tabscope")

describe("tabscope", function()
  describe("config", function()
    it("is a table", function()
      assert.is_table(tabscope.config)
    end)

    it("has tablabel config", function()
      assert.is_table(tabscope.config.tablabel)
    end)

    it("has bufferlist config", function()
      assert.is_table(tabscope.config.bufferlist)
    end)

    it("tablabel config has enable", function()
      assert.is_boolean(tabscope.config.tablabel.enable)
    end)

    it("bufferlist config has enable", function()
      assert.is_boolean(tabscope.config.bufferlist.enable)
    end)

    it("bufferlist config has hijack", function()
      assert.is_boolean(tabscope.config.bufferlist.hijack)
    end)
  end)

  describe("setup", function()
    it("works with tablabel config", function()
      assert.has_no_error(function()
        tabscope.setup({ tablabel = { enable = false } })
      end)
    end)

    it("works with bufferlist config", function()
      assert.has_no_error(function()
        tabscope.setup({ bufferlist = { enable = false, hijack = false } })
      end)
    end)

    it("works with both configs", function()
      assert.has_no_error(function()
        tabscope.setup({
          tablabel = { enable = false },
          bufferlist = { enable = false, hijack = false },
        })
      end)
    end)

    it("works without args", function()
      assert.has_no_error(function()
        tabscope.setup()
      end)
    end)

    it("merges configs", function()
      local original = vim.deepcopy(tabscope.config)
      tabscope.setup({ tablabel = { enable = false } })
      assert.is_false(tabscope.config.tablabel.enable)
      tabscope.config = original
    end)
  end)
end)