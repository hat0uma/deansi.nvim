local Parser = require("deansi.parser").Parser

describe("deansi.Parser", function()
  local parser

  before_each(function()
    parser = Parser:new()
  end)

  describe("parse", function()
    it("should call callbacks for text without ANSI codes", function()
      local texts = {}
      local commands = {}
      local errors = {}

      local callback = {
        on_text = function(start, stop, text)
          table.insert(texts, { start = start, stop = stop, text = text })
        end,
        on_command = function(cmd)
          table.insert(commands, cmd)
        end,
        on_error = function(err)
          table.insert(errors, err)
        end,
      }

      parser:parse("Hello World", callback)

      assert.are.equal(1, #texts)
      assert.are.equal("Hello World", texts[1].text)
      assert.are.equal(0, texts[1].start.lnum)
      assert.are.equal(0, texts[1].start.col)
      assert.are.equal(0, texts[1].stop.lnum)
      assert.are.equal(10, texts[1].stop.col)
      assert.are.same({}, commands)
      assert.are.same({}, errors)
    end)

    it("should parse simple SGR reset", function()
      local texts = {}
      local commands = {}
      local errors = {}

      local callback = {
        on_text = function(start, stop, text)
          table.insert(texts, { start = start, stop = stop, text = text })
        end,
        on_command = function(cmd)
          table.insert(commands, cmd)
        end,
        on_error = function(err)
          table.insert(errors, err)
        end,
      }

      parser:parse("Hello\27[0mWorld", callback)

      assert.are.equal(2, #texts)
      assert.are.equal("Hello", texts[1].text)
      assert.are.equal("World", texts[2].text)
      assert.are.equal(1, #commands)
      assert.are.equal("sgr", commands[1].type)
      assert.are.same({ 0 }, commands[1].params)
      assert.are.same({}, errors)
    end)

    it("should parse basic color codes", function()
      local texts = {}
      local commands = {}
      local errors = {}

      local callback = {
        on_text = function(start, stop, text)
          table.insert(texts, { start = start, stop = stop, text = text })
        end,
        on_command = function(cmd)
          table.insert(commands, cmd)
        end,
        on_error = function(err)
          table.insert(errors, err)
        end,
      }

      parser:parse("\27[31mRed Text\27[0m", callback)

      assert.are.equal(1, #texts)
      assert.are.equal("Red Text", texts[1].text)
      assert.are.equal(2, #commands)

      -- First command: red foreground
      assert.are.equal("sgr", commands[1].type)
      assert.are.same({ 31 }, commands[1].params)

      -- Second command: reset
      assert.are.equal("sgr", commands[2].type)
      assert.are.same({ 0 }, commands[2].params)
      assert.are.same({}, errors)
    end)

    it("should parse bold and color combination", function()
      local texts = {}
      local commands = {}
      local errors = {}

      local callback = {
        on_text = function(start, stop, text)
          table.insert(texts, { start = start, stop = stop, text = text })
        end,
        on_command = function(cmd)
          table.insert(commands, cmd)
        end,
        on_error = function(err)
          table.insert(errors, err)
        end,
      }

      parser:parse("\27[1;32mBold Green\27[0m", callback)

      assert.are.equal(1, #texts)
      assert.are.equal("Bold Green", texts[1].text)
      assert.are.equal(2, #commands)
      assert.are.same({ 1, 32 }, commands[1].params)
      assert.are.same({}, errors)
    end)

    it("should parse 256-color codes", function()
      local texts = {}
      local commands = {}
      local errors = {}

      local callback = {
        on_text = function(start, stop, text)
          table.insert(texts, { start = start, stop = stop, text = text })
        end,
        on_command = function(cmd)
          table.insert(commands, cmd)
        end,
        on_error = function(err)
          table.insert(errors, err)
        end,
      }

      parser:parse("\27[38;5;196mBright Red\27[0m", callback)

      assert.are.equal(1, #texts)
      assert.are.equal("Bright Red", texts[1].text)
      assert.are.equal(2, #commands)
      assert.are.same({ 38, 5, 196 }, commands[1].params)
      assert.are.same({}, errors)
    end)

    it("should parse 24-bit RGB color codes", function()
      local texts = {}
      local commands = {}
      local errors = {}

      local callback = {
        on_text = function(start, stop, text)
          table.insert(texts, { start = start, stop = stop, text = text })
        end,
        on_command = function(cmd)
          table.insert(commands, cmd)
        end,
        on_error = function(err)
          table.insert(errors, err)
        end,
      }

      parser:parse("\27[38;2;255;128;64mOrange Text\27[0m", callback)

      assert.are.equal(1, #texts)
      assert.are.equal("Orange Text", texts[1].text)
      assert.are.equal(2, #commands)
      assert.are.same({ 38, 2, 255, 128, 64 }, commands[1].params)
      assert.are.same({}, errors)
    end)

    it("should parse 24-bit RGB color codes with colon separators (ITU-T T.416)", function()
      local texts = {}
      local commands = {}
      local errors = {}

      local callback = {
        on_text = function(start, stop, text)
          table.insert(texts, { start = start, stop = stop, text = text })
        end,
        on_command = function(cmd)
          table.insert(commands, cmd)
        end,
        on_error = function(err)
          table.insert(errors, err)
        end,
      }

      -- Test the new ITU-T T.416 format: ESC[38:2::R:G:Bm
      parser:parse("\27[38:2::26:43:21mCustom Color\27[0m", callback)

      assert.are.equal(1, #texts)
      assert.are.equal("Custom Color", texts[1].text)
      assert.are.equal(2, #commands)
      assert.are.same({ 38, 2, vim.NIL, 26, 43, 21 }, commands[1].params)
      assert.are.same({}, errors)
    end)

    it("should parse mixed colon and semicolon separators", function()
      local texts = {}
      local commands = {}
      local errors = {}

      local callback = {
        on_text = function(start, stop, text)
          table.insert(texts, { start = start, stop = stop, text = text })
        end,
        on_command = function(cmd)
          table.insert(commands, cmd)
        end,
        on_error = function(err)
          table.insert(errors, err)
        end,
      }

      -- Test mixed separators: ESC[1;38:5:196m
      parser:parse("\27[1;38:5:196mBold Bright Red\27[0m", callback)

      assert.are.equal(1, #texts)
      assert.are.equal("Bold Bright Red", texts[1].text)
      assert.are.equal(2, #commands)
      assert.are.same({ 1, 38, 5, 196 }, commands[1].params)
      assert.are.same({}, errors)
    end)

    it("should parse background colors", function()
      local texts = {}
      local commands = {}
      local errors = {}

      local callback = {
        on_text = function(start, stop, text)
          table.insert(texts, { start = start, stop = stop, text = text })
        end,
        on_command = function(cmd)
          table.insert(commands, cmd)
        end,
        on_error = function(err)
          table.insert(errors, err)
        end,
      }

      parser:parse("\27[48;2;0;0;255mBlue Background\27[0m", callback)

      assert.are.equal(1, #texts)
      assert.are.equal("Blue Background", texts[1].text)
      assert.are.equal(2, #commands)
      assert.are.same({ 48, 2, 0, 0, 255 }, commands[1].params)
      assert.are.same({}, errors)
    end)

    it("should handle multiple escape sequences", function()
      local texts = {}
      local commands = {}
      local errors = {}

      local callback = {
        on_text = function(start, stop, text)
          table.insert(texts, { start = start, stop = stop, text = text })
        end,
        on_command = function(cmd)
          table.insert(commands, cmd)
        end,
        on_error = function(err)
          table.insert(errors, err)
        end,
      }

      parser:parse("\27[1mBold\27[0m \27[31mRed\27[0m", callback)

      assert.are.equal(3, #texts)
      assert.are.equal("Bold", texts[1].text)
      assert.are.equal(" ", texts[2].text)
      assert.are.equal("Red", texts[3].text)
      assert.are.equal(4, #commands)
      assert.are.same({}, errors)
    end)

    it("should handle empty SGR parameters", function()
      local texts = {}
      local commands = {}
      local errors = {}

      local callback = {
        on_text = function(start, stop, text)
          table.insert(texts, { start = start, stop = stop, text = text })
        end,
        on_command = function(cmd)
          table.insert(commands, cmd)
        end,
        on_error = function(err)
          table.insert(errors, err)
        end,
      }

      parser:parse("\27[mReset\27[0m", callback)

      assert.are.equal(1, #texts)
      assert.are.equal("Reset", texts[1].text)
      assert.are.equal(2, #commands)
      assert.are.same({ 0 }, commands[1].params)
      assert.are.same({}, errors)
    end)

    it("should handle malformed escape sequences", function()
      local texts = {}
      local commands = {}
      local errors = {}

      local callback = {
        on_text = function(start, stop, text)
          table.insert(texts, { start = start, stop = stop, text = text })
        end,
        on_command = function(cmd)
          table.insert(commands, cmd)
        end,
        on_error = function(err)
          table.insert(errors, err)
        end,
      }

      parser:parse("Hello\27[World", callback)

      assert.are.equal(3, #texts)
      assert.are.equal("Hello", texts[1].text)
      assert.are.equal("\27", texts[2].text)
      assert.are.equal("World", texts[3].text)
      assert.are.equal(0, #commands)
      assert.are.equal(1, #errors)
      assert.is_true(errors[1]:find("Invalid escape sequence"))
    end)

    it("should handle non-SGR escape sequences", function()
      local texts = {}
      local commands = {}
      local errors = {}

      local callback = {
        on_text = function(start, stop, text)
          table.insert(texts, { start = start, stop = stop, text = text })
        end,
        on_command = function(cmd)
          table.insert(commands, cmd)
        end,
        on_error = function(err)
          table.insert(errors, err)
        end,
      }

      parser:parse("Hello\27[2JWorld", callback)

      assert.are.equal(2, #texts)
      assert.are.equal("Hello", texts[1].text)
      assert.are.equal("World", texts[2].text)
      assert.are.equal(1, #commands)
      assert.are.equal("other", commands[1].type)
      assert.are.same({}, errors)
    end)

    it("should provide correct position ranges", function()
      local texts = {}
      local commands = {} ---@type deansi.AnsiCommand[]
      local errors = {} ---@type string[]

      local callback = {
        on_text = function(start, stop, text)
          table.insert(texts, { start = start, stop = stop, text = text })
        end,
        on_command = function(cmd)
          table.insert(commands, cmd)
        end,
        on_error = function(err)
          table.insert(errors, err)
        end,
      }

      parser:parse("ABC\27[31mDEF\27[0mGHI", callback)

      assert.are.equal(3, #texts, string.format("Expected 3 text segments, got %d(%s)", #texts, vim.inspect(texts)))
      assert.are.equal(2, #commands)

      -- "ABC" at positions 0-2 (0-based)
      assert.are.equal("ABC", texts[1].text)
      assert.are.equal(0, texts[1].start.col)
      assert.are.equal(2, texts[1].stop.col)

      assert.are.equal("sgr", commands[1].type)
      assert.are.same({ 31 }, commands[1].params)
      assert.are.same(3, commands[1].start.col)
      assert.are.same(7, commands[1].stop.col)

      -- "DEF" at positions 8-10 (after escape sequence)
      assert.are.equal("DEF", texts[2].text)
      assert.are.equal(8, texts[2].start.col)
      assert.are.equal(10, texts[2].stop.col)

      assert.are.equal("sgr", commands[2].type)
      assert.are.same({ 0 }, commands[2].params)
      assert.are.same(11, commands[2].start.col)
      assert.are.same(14, commands[2].stop.col)

      -- "GHI" at positions 16-18 (after second escape sequence)
      assert.are.equal("GHI", texts[3].text)
      assert.are.equal(15, texts[3].start.col)
      assert.are.equal(17, texts[3].stop.col)
    end)
  end)
  describe("complex real-world examples", function()
    it("should parse complex prompt with multiple styles", function()
      local texts = {}
      local commands = {}
      local errors = {}

      local callback = {
        on_text = function(start, stop, text)
          table.insert(texts, { start = start, stop = stop, text = text })
        end,
        on_command = function(cmd)
          table.insert(commands, cmd)
        end,
        on_error = function(err)
          table.insert(errors, err)
        end,
      }

      local text = "\27[0;1m\27[32mtest@hello\27[0m:\27[0;1m\27[34m~\27[0m$ "
      parser:parse(text, callback)

      assert.are.equal(4, #texts)
      assert.are.equal("test@hello", texts[1].text)
      assert.are.equal(":", texts[2].text)
      assert.are.equal("~", texts[3].text)
      assert.are.equal("$ ", texts[4].text)
      assert.are.equal(6, #commands)
      assert.are.same({}, errors)
    end)

    it("should handle hyperlinks", function()
      local texts = {}
      local commands = {}
      local errors = {}

      local callback = {
        on_text = function(start, stop, text)
          table.insert(texts, { start = start, stop = stop, text = text })
        end,
        on_command = function(cmd)
          table.insert(commands, cmd)
        end,
        on_error = function(err)
          table.insert(errors, err)
        end,
      }

      local text = "]8;;http://example.com\\Example]8;;\\"
      parser:parse(text, callback)

      -- This should be treated as regular text since it's not a proper escape sequence
      assert.are.equal(1, #texts)
      assert.are.equal(text, texts[1].text)
      assert.are.equal(0, #commands)
      assert.are.same({}, errors)
    end)
  end)
end)
