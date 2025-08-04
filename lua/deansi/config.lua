local M = {}

--- @class deansi.Options

--- @class deansi.InternalOptions
M.defaults = {}

---@diagnostic disable-next-line: missing-fields
M.options = {}

--- Get configuration options for deansi.
---@param opts deansi.Options
---@return deansi.InternalOptions
function M.get(opts)
  return vim.tbl_deep_extend("force", M.defaults, opts or {})
end

--- Setup deansi with the given options.
---@param opts deansi.Options
function M.setup(opts)
  M.options = M.get(opts)
end

return M
