local M = {}

---@alias deansi.Color
--- | string -- Standard color names (e.g., "Red", "Green", "Blue") or 24-bit RGB color codes (e.g., "#ff0000")
--- | integer -- 256-color index (0-255)

---@class deansi.Style
---@field fg deansi.Color? Foreground color
---@field bg deansi.Color? Background color
---@field bold boolean?
---@field dim boolean?
---@field italic boolean?
---@field underline boolean?
---@field blink boolean?
---@field reverse boolean?
---@field strikethrough boolean?

local COLORS_16 = {
  [1] = "Black",
  [2] = "DarkRed",
  [3] = "DarkGreen",
  [4] = "Brown",
  [5] = "DarkBlue",
  [6] = "DarkMagenta",
  [7] = "DarkCyan",
  [8] = "Gray",
  [9] = "DarkGray",
  [10] = "Red",
  [11] = "Green",
  [12] = "Yellow",
  [13] = "Blue",
  [14] = "Magenta",
  [15] = "Cyan",
  [16] = "White",
}

---@enum deansi.SGR.Code
local SGR = {
  RESET = 0,
  BOLD = 1,
  DIM = 2,
  ITALIC = 3,
  UNDERLINE = 4,
  SLOW_BLINK = 5,
  RAPID_BLINK = 6,
  REVERSE = 7,
  STRIKETHROUGH = 9,
  NORMAL_INTENSITY = 22,
  NEITHER_ITALIC_NOR_BLACK_LETTER = 23,
  NOT_UNDERLINED = 24,
  NOT_BLINKING = 25,
  NOT_REVERSED = 27,
  NOT_CROSSED_OUT = 29,
  -- foreground colors (16-color mode)
  SET_FG_COLOR_1 = 30,
  SET_FG_COLOR_2 = 31,
  SET_FG_COLOR_3 = 32,
  SET_FG_COLOR_4 = 33,
  SET_FG_COLOR_5 = 34,
  SET_FG_COLOR_6 = 35,
  SET_FG_COLOR_7 = 36,
  SET_FG_COLOR_8 = 37,
  -- 24-bit RGB foreground color
  SET_FG_COLOR_RGB = 38,
  DEFAULT_FG_COLOR = 39,
  -- background colors (16-color mode)
  SET_BG_COLOR_1 = 40,
  SET_BG_COLOR_2 = 41,
  SET_BG_COLOR_3 = 42,
  SET_BG_COLOR_4 = 43,
  SET_BG_COLOR_5 = 44,
  SET_BG_COLOR_6 = 45,
  SET_BG_COLOR_7 = 46,
  SET_BG_COLOR_8 = 47,
  -- 24-bit RGB background color
  SET_BG_COLOR_RGB = 48,
  DEFAULT_BG_COLOR = 49,
  -- Bright foreground colors (16-color mode)
  SET_FG_COLOR_BRIGHT_1 = 90,
  SET_FG_COLOR_BRIGHT_2 = 91,
  SET_FG_COLOR_BRIGHT_3 = 92,
  SET_FG_COLOR_BRIGHT_4 = 93,
  SET_FG_COLOR_BRIGHT_5 = 94,
  SET_FG_COLOR_BRIGHT_6 = 95,
  SET_FG_COLOR_BRIGHT_7 = 96,
  SET_FG_COLOR_BRIGHT_8 = 97,
  -- Bright background colors (16-color mode)
  SET_BG_COLOR_BRIGHT_1 = 100,
  SET_BG_COLOR_BRIGHT_2 = 101,
  SET_BG_COLOR_BRIGHT_3 = 102,
  SET_BG_COLOR_BRIGHT_4 = 103,
  SET_BG_COLOR_BRIGHT_5 = 104,
  SET_BG_COLOR_BRIGHT_6 = 105,
  SET_BG_COLOR_BRIGHT_7 = 106,
  SET_BG_COLOR_BRIGHT_8 = 107,
}

--- Convert an index to a color name
---@param idx integer Index of the color (1-8)
---@param bright boolean Whether to use bright colors
---@return string Color name
function M.idx_to_color(idx, bright)
  -- Adjust index for bright colors
  idx = bright and (idx + 8) or idx

  if idx < 1 or idx > #COLORS_16 then
    error("Index out of range: " .. idx)
  end

  return COLORS_16[idx]
end

local function rgb_to_hex(r, g, b)
  return string.format("#%02x%02x%02x", r, g, b)
end

--- Process a color escape sequence.
---@param params number[]
---@param i integer
---@return integer Next index to process
---@return integer|string? color_value
function M.process_color(params, i)
  -- Process both 8-bit and 24-bit color escape sequences
  local color_type = params[i + 1]
  local color_value ---@type integer|string?
  if color_type == 5 and params[i + 2] then
    -- 8-bit color (256 colors)
    color_value = params[i + 2]
    if color_value < 0 or color_value > 255 then
      error("Invalid 8-bit color value: " .. color_value)
    end
    i = i + 2
  elseif color_type == 2 then
    -- 24-bit RGB color
    i, color_value = M.process_24bit_color(params, i)
  else
    -- Unknown color type, skip it
    i = i + 1
  end

  return i, color_value
end

--- Process a true color escape sequence.
---@param params number[]
---@param i integer
---@return integer Next index to process
---@return string? color_code hex color code
function M.process_24bit_color(params, i)
  -- 24-bit RGB color
  -- Traditional format: 38;2;r;g;b
  -- ITU-T T.416 format: 38:2::r:g:b or 38:2:colorspace:r:g:b
  local next_idx = i + 2
  local color_code ---@type string?

  -- Skip color space parameter if present (ITU-T T.416)
  -- In the format 38:2::r:g:b, there's an empty color space parameter
  -- In the format 38:2:0:r:g:b, 0 indicates default sRGB color space
  if next_idx <= #params and next_idx + 3 <= #params then
    -- NOTE: Currently, we only handle the default sRGB color space
    ---@diagnostic disable-next-line: unused-local
    local colorspace = params[next_idx]
    local r, g, b = params[next_idx + 1], params[next_idx + 2], params[next_idx + 3]
    color_code = rgb_to_hex(r, g, b)
    i = next_idx + 3
  elseif next_idx <= #params and next_idx + 2 <= #params then
    -- Traditional format without color space: 38;2;r;g;b
    local r, g, b = params[next_idx], params[next_idx + 1], params[next_idx + 2]
    color_code = rgb_to_hex(r, g, b)
    i = next_idx + 2
  else
    i = i + 1
  end

  return i, color_code
end

--- Update the style based on SGR parameters
---@param params number[]
---@param current_style deansi.Style? Current style to extend
---@return deansi.Style
function M.update_style(params, current_style)
  local style = current_style or {}
  local i = 1

  while i <= #params do
    local code = params[i] ---@type deansi.SGR.Code

    if code == SGR.RESET then
      -- Reset all attributes
      style = {}
    elseif code == SGR.BOLD then
      style.bold = true
    elseif code == SGR.DIM then
      style.dim = true
    elseif code == SGR.ITALIC then
      style.italic = true
    elseif code == SGR.UNDERLINE then
      style.underline = true
    elseif code == SGR.SLOW_BLINK or code == SGR.RAPID_BLINK then
      style.blink = true
    elseif code == SGR.REVERSE then
      style.reverse = true
    elseif code == SGR.STRIKETHROUGH then
      style.strikethrough = true
    elseif code == SGR.NORMAL_INTENSITY then
      style.bold = false
      style.dim = false
    elseif code == SGR.NEITHER_ITALIC_NOR_BLACK_LETTER then
      style.italic = false
    elseif code == SGR.NOT_UNDERLINED then
      style.underline = false
    elseif code == SGR.NOT_BLINKING then
      style.blink = false
    elseif code == SGR.NOT_REVERSED then
      style.reverse = false
    elseif code == SGR.NOT_CROSSED_OUT then
      style.strikethrough = false
    elseif code >= SGR.SET_FG_COLOR_1 and code <= SGR.SET_FG_COLOR_8 then
      style.fg = M.idx_to_color(code - SGR.SET_FG_COLOR_1 + 1, false)
    elseif code == SGR.SET_FG_COLOR_RGB then
      local color_value ---@type integer|string?
      i, color_value = M.process_color(params, i)
      style.fg = color_value and color_value or style.fg
    elseif code == SGR.DEFAULT_FG_COLOR then
      style.fg = nil
    elseif code >= SGR.SET_BG_COLOR_1 and code <= SGR.SET_BG_COLOR_8 then
      style.bg = M.idx_to_color(code - SGR.SET_BG_COLOR_1 + 1, false)
    elseif code == SGR.SET_BG_COLOR_RGB then
      local color_value ---@type integer|string?
      i, color_value = M.process_color(params, i)
      style.bg = color_value and color_value or style.bg
    elseif code == SGR.DEFAULT_BG_COLOR then
      style.bg = nil
    elseif code >= SGR.SET_FG_COLOR_BRIGHT_1 and code <= SGR.SET_FG_COLOR_BRIGHT_8 then
      style.fg = M.idx_to_color(code - SGR.SET_FG_COLOR_BRIGHT_1 + 1, true)
    elseif code >= SGR.SET_BG_COLOR_BRIGHT_1 and code <= SGR.SET_BG_COLOR_BRIGHT_8 then
      -- Bright background colors
      style.bg = M.idx_to_color(code - SGR.SET_BG_COLOR_BRIGHT_1 + 1, true)
    end

    i = i + 1
  end

  return style
end

return M
