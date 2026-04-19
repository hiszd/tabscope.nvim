local tabscope = require("tabscope")

describe("tabscope", function()
  it("has config", function()
    assert.is_table(tabscope.config)
  end)

  it("setup works with tablabel config", function()
    assert.has_no_error(function()
      tabscope.setup({ tablabel = { enable = false } })
    end)
  end)

  it("setup works without args", function()
    assert.has_no_error(function()
      tabscope.setup()
    end)
  end)
end)
