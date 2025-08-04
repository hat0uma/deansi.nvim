local config = require("deansi.config")
local Parser = require("deansi.parser").Parser
local M = {}

local ns = vim.api.nvim_create_namespace("deansi")

--- @param opts deansi.Options
function M.setup(opts)
  config.setup(opts)

  vim.api.nvim_create_user_command("DeansiEnable", function()
    M.enable(opts)
  end, { desc = "Enable deansi", nargs = 0 })
  vim.api.nvim_create_user_command("DeansiDisable", function()
    M.disable(opts)
  end, { desc = "Disable deansi", nargs = 0 })
  vim.api.nvim_create_user_command("DeansiToggle", function()
    M.toggle(opts)
  end, { desc = "Toggle deansi", nargs = 0 })
end

function M.is_enabled() end

---@param opts deansi.Options
function M.enable(opts)
  ---@diagnostic disable-next-line: cast-local-type
  opts = config.get(opts)

  local bufnr = vim.api.nvim_get_current_buf() -- TODO
  vim.wo[0][0].conceallevel = 2
  vim.wo[0][0].concealcursor = "nvc"

  local current_style = {} ---@type deansi.Style
  local index = 0
  local style_map = {} ---@type table<string, string> -- map of style key to highlight group name
  local parser = Parser:new()
  parser:parse_buf(bufnr, {
    on_command = function(command)
      -- conceal the command
      vim.api.nvim_buf_set_extmark(bufnr, ns, command.start.lnum, command.start.col, {
        end_row = command.stop.lnum,
        end_col = command.stop.col + 1, -- last col is exclusive
        conceal = "",
      })

      if command.type == "sgr" then
        current_style = require("deansi.sgr").update_style(command.params, current_style)
      end
    end,
    on_error = function(err)
      vim.notify("Error parsing ANSI escape codes: " .. err, vim.log.levels.ERROR)
    end,
    on_text = function(start, stop, text)
      if not current_style or vim.tbl_isempty(current_style) then
        return
      end

      -- TODO: properly dedup styles
      local style_key = require("string.buffer").encode(current_style)
      if not style_map[style_key] then
        -- define the highlight group based on the current style
        local hl_group = "Deansi_" .. index
        index = index + 1
        vim.api.nvim_set_hl(0, hl_group, {
          fg = current_style.fg,
          bg = current_style.bg,
          bold = current_style.bold,
          italic = current_style.italic,
          underline = current_style.underline,
          strikethrough = current_style.strikethrough,
        })
        style_map[style_key] = hl_group
      end

      -- highlight the text with the current style
      vim.api.nvim_buf_set_extmark(bufnr, ns, start.lnum, start.col, {
        end_row = stop.lnum,
        end_col = stop.col + 1, -- last col is exclusive
        hl_group = style_map[style_key],
      })
    end,
  })
end

---@param opts deansi.Options
function M.disable(opts)
  ---@diagnostic disable-next-line: cast-local-type
  opts = config.get(opts)

  -- TODO to properly disable deansi
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
end

--- Toggle deansi
---@param opts deansi.Options
function M.toggle(opts)
  if M.is_enabled() then
    M.disable(opts)
  else
    M.enable(opts)
  end
end

return M
