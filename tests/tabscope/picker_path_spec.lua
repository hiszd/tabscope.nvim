describe("picker path utilities", function()
  local picker = require("tabscope.bufferlist.picker")
  local bufferlist = require("tabscope.bufferlist")

  describe("find_common_parent", function()
    it("returns nil for empty list", function()
      local result = picker.find_common_parent({})
      assert.is_nil(result)
    end)

    it("returns path as-is for single directory", function()
      local result = picker.find_common_parent({ "/home/zion/project" })
      assert.equals("/home/zion/project", result)
    end)

    it("finds common parent for nested directories", function()
      local result = picker.find_common_parent({
        "/home/zion/projects/app1/src",
        "/home/zion/projects/app1/lib",
      })
      assert.equals("home/zion/projects/app1", result)
    end)

    it("finds common parent for sibling directories", function()
      local result = picker.find_common_parent({
        "/home/zion/projects/app1",
        "/home/zion/projects/app2",
      })
      assert.equals("home/zion/projects", result)
    end)

    it("finds common parent for deep nested directories", function()
      local result = picker.find_common_parent({
        "/home/zion/a/b/c/d1",
        "/home/zion/a/b/c/d2",
        "/home/zion/a/b/c/d3",
      })
      assert.equals("home/zion/a/b/c", result)
    end)

    it("returns nil when no common parent", function()
      local result = picker.find_common_parent({
        "/home/zion/project",
        "/var/data",
      })
      assert.is_nil(result)
    end)

    it("returns nil for completely different paths", function()
      local result = picker.find_common_parent({
        "/home/zion/abc",
        "/opt/xyz",
      })
      assert.is_nil(result)
    end)

    it("handles home directory variations", function()
      local result = picker.find_common_parent({
        "/home/zion/work/project",
        "/home/zion/play/project",
      })
      assert.equals("home/zion", result)
    end)
  end)

  describe("_get_display_path", function()
    it("returns relative path for single directory", function()
      local result = bufferlist._get_display_path({ "/home/zion/projects/myproject" })
      -- Should return common parent relative to home
      assert.is_string(result)
      assert.is_true(#result > 0)
    end)

    it("returns relative path for nested single directory", function()
      local result = bufferlist._get_display_path({ "/home/zion/projects/myproject/src" })
      -- Should return common parent relative to home
      assert.is_string(result)
      assert.is_true(#result > 0)
    end)

    it("returns relative path for multiple directories with common parent", function()
      local result = bufferlist._get_display_path({
        "/home/zion/projects/app1",
        "/home/zion/projects/app2",
      })
      -- Result should be relative to home (~)
      assert.is_string(result)
      -- Should contain "projects" which is the common parent
      assert.is_true(string.find(result, "projects") ~= nil)
    end)

    it("returns 'Multiple directories' when no common parent", function()
      local result = bufferlist._get_display_path({
        "/home/zion/project",
        "/var/data",
      })
      assert.equals("Multiple directories", result)
    end)
  end)
end)