local M = {}

local ESC = string.char(0x1B)
local CSI = ESC .. "["

---@class deansi.Range
---@field lnum number Start line number(0-based)
---@field col number Start column number(0-based)

---@alias deansi.AnsiCommand deansi.AnsiCommand.SGR | deansi.AnsiCommand.Other

---@class deansi.AnsiCommand.SGR
---@field type "sgr"
---@field start deansi.Range Start position in the text
---@field stop deansi.Range End position in the text.
---@field params number[] SGR parameters (e.g., {1, 31} for bold red text)

---@class deansi.AnsiCommand.Other
---@field type "other"
---@field start deansi.Range Start position in the text
---@field stop deansi.Range End position in the text.

---@class deansi.Parser.Callback
---@field on_command fun(command: deansi.AnsiCommand)
---@field on_text fun(start: deansi.Range, stop: deansi.Range, text: string)
---@field on_error fun(err: string)

---@class deansi.Parser
local Parser = {}
Parser.__index = Parser

--- Create a new Parser.
---@return deansi.Parser
function Parser:new()
  local obj = {}
  setmetatable(obj, self)
  return obj
end

--- Parse a buffer
---@param bufnr number The buffer number to parse
---@param callback deansi.Parser.Callback Callback functions for handling parsed elements
function Parser:parse_buf(bufnr, callback)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  for lnum = 0, line_count do
    local text = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or ""
    self:parse(text, callback, lnum)
  end
end

--- Parse text with ANSI escape codes using callback pattern
---@param text string The text containing ANSI escape codes
---@param callback deansi.Parser.Callback Callback functions for handling parsed elements
---@param lnum number?
function Parser:parse(text, callback, lnum)
  lnum = lnum or 0
  local pos = 1

  while pos <= #text do
    local esc_start = text:find(ESC, pos)
    if not esc_start then
      -- No more escape sequences, handle remaining text
      if pos <= #text then
        local remaining_text = text:sub(pos)
        if #remaining_text > 0 then
          local start_range = { lnum = lnum, col = (pos - 1) }
          local stop_range = { lnum = lnum, col = start_range.col + #remaining_text - 1 }
          callback.on_text(start_range, stop_range, remaining_text)
        end
      end
      break
    end

    -- Handle text before escape sequence
    if esc_start > pos then
      local before_text = text:sub(pos, esc_start - 1)
      local start_range = { lnum = lnum, col = (pos - 1) }
      local stop_range = { lnum = lnum, col = (esc_start - 1) - 1 }
      callback.on_text(start_range, stop_range, before_text)
    end

    -- Parse escape sequence
    local seq_start = esc_start
    local seq_end = self:_find_sequence_end(text, esc_start)

    if seq_end then
      local sequence = text:sub(seq_start, seq_end)
      local command = self:_parse_escape_sequence(sequence, lnum, seq_start, seq_end)

      if command then
        callback.on_command(command)
      else
        callback.on_error("Failed to parse escape sequence: " .. sequence)
      end

      pos = seq_end + 1
    else
      -- Invalid escape sequence, treat as regular text and report error
      local invalid_seq = text:sub(esc_start, esc_start)
      local start_range = { lnum = lnum, col = (esc_start - 1) }
      local stop_range = { lnum = lnum, col = (esc_start - 1) }
      callback.on_text(start_range, stop_range, invalid_seq)
      callback.on_error("Invalid escape sequence at position " .. esc_start)
      pos = esc_start + 1
    end
  end
end

--- Find the end of an ANSI escape sequence
---@param text string
---@param start number
---@return number|nil
function Parser:_find_sequence_end(text, start)
  local pos = start + 1 -- Skip ESC character

  if pos > #text then
    return nil
  end

  -- Check for CSI (Control Sequence Introducer): ESC[
  if text:sub(pos, pos) == "[" then
    pos = pos + 1
    -- Find the final character (A-Z, a-z)
    while pos <= #text do
      local char = text:sub(pos, pos)
      if char:match("[A-Za-z]") then
        return pos
      elseif char:match("[0-9;:<=>?@]") then
        pos = pos + 1
      else
        -- Invalid character in CSI sequence
        return nil
      end
    end
  end

  -- Check for other escape sequences
  -- ESC( for character set selection
  -- ESC) for character set selection
  -- ESC] for operating system commands
  if pos <= #text and text:sub(pos, pos):match("[()%]^_]") then
    pos = pos + 1
    -- For OSC sequences (ESC]), find ST (String Terminator) or BEL
    if text:sub(pos - 1, pos - 1) == "]" then
      while pos <= #text do
        local char = text:sub(pos, pos)
        if char == "\07" then -- BEL
          return pos
        elseif char == ESC and pos + 1 <= #text and text:sub(pos + 1, pos + 1) == "\\" then -- ST
          return pos + 1
        end
        pos = pos + 1
      end
    elseif pos <= #text then
      return pos
    end
  end

  return nil
end

--- Parse an escape sequence into a command
---@param sequence string
---@param lnum number 0-based line number
---@param start_pos number 1-based
---@param end_pos number 1-based
---@return deansi.AnsiCommand|nil
function Parser:_parse_escape_sequence(sequence, lnum, start_pos, end_pos)
  -- Convert position to line/column format
  local start_range = { lnum = lnum, col = start_pos - 1 }
  local stop_range = { lnum = lnum, col = end_pos - 1 }

  -- Handle CSI sequences (ESC[...)
  if vim.startswith(sequence, CSI) then
    local params_str = sequence:sub(3, -2) -- Remove ESC[ and final character
    local final_char = sequence:sub(-1)

    -- SGR (Select Graphic Rendition) - ESC[...m
    if final_char == "m" then
      local params = {}
      if params_str ~= "" then
        -- Support both semicolon (;) and colon (:) separators
        local _params = vim.split(params_str, "[;:]")
        -- for param in params_str:gmatch("([^;:]+)") do
        for _, param in ipairs(_params) do
          local num = tonumber(param)
          if num then
            table.insert(params, num)
          else
            -- Handle empty parameters as 0
            table.insert(params, vim.NIL)
          end
        end
      else
        -- Empty parameters default to 0 (reset)
        params = { 0 }
      end

      return {
        type = "sgr",
        start = start_range,
        stop = stop_range,
        params = params,
      }
    end

    -- Other CSI sequences
    return {
      type = "other",
      start = start_range,
      stop = stop_range,
    }
  end

  -- Non-CSI escape sequences
  return {
    type = "other",
    start = start_range,
    stop = stop_range,
  }
end

M.Parser = Parser

return M
