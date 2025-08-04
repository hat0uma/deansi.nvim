local sgr = require("deansi.sgr")

describe("update_style", function()
  it("should convert reset parameter", function()
    local style = sgr.update_style({ 0 })
    assert.are.same({}, style)
  end)

  it("should convert basic formatting", function()
    local style = sgr.update_style({ 1, 3, 4 })
    assert.is_true(style.bold)
    assert.is_true(style.italic)
    assert.is_true(style.underline)
  end)

  it("should convert standard colors", function()
    local style = sgr.update_style({ 31, 42 })
    assert.are.equal("DarkRed", style.fg) -- red
    assert.are.equal("DarkGreen", style.bg) -- green
  end)

  it("should convert bright colors", function()
    local style = sgr.update_style({ 91, 102 })
    assert.are.equal("Red", style.fg) -- bright_red
    assert.are.equal("Green", style.bg) -- bright_green
  end)

  it("should convert 256-color", function()
    local style = sgr.update_style({ 38, 5, 196 })
    assert.are.equal(196, style.fg) -- 256-color index
  end)

  it("should convert 24-bit RGB color", function()
    local style = sgr.update_style({ 38, 2, 255, 128, 64 })
    assert.are.equal("#ff8040", style.fg)
  end)

  it("should convert 24-bit RGB color with ITU-T T.416 format (with color space)", function()
    -- Format: 38:2:0:r:g:b (0 = default sRGB color space)
    local style = sgr.update_style({ 38, 2, 0, 26, 43, 21 })
    assert.are.equal("#1a2b15", style.fg)
  end)

  it("should convert 24-bit RGB color with ITU-T T.416 format (empty color space)", function()
    -- Format: 38:2::r:g:b (empty color space defaults to sRGB)
    local style = sgr.update_style({ 38, 2, 0, 26, 43, 21 })
    assert.are.equal("#1a2b15", style.fg)
  end)

  it("should convert background 24-bit RGB color with ITU-T T.416 format", function()
    -- Format: 48:2:0:r:g:b
    local style = sgr.update_style({ 48, 2, 0, 100, 150, 200 })
    assert.are.equal("#6496c8", style.bg)
  end)

  it("should handle reset attributes", function()
    local style = sgr.update_style({ 1, 22 })
    assert.is_false(style.bold)
  end)

  it("should handle default colors", function()
    local style = sgr.update_style({ 31, 39 })
    assert.is_nil(style.fg)
  end)
end)
