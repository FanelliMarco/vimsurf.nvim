---@class VimSurfConfig
---@field enabled boolean
---@field api_url string
---@field model string
---@field user_id string?
---@field username string?
---@field password string?
---@field max_tokens integer
---@field temperature number
---@field debounce_ms integer
---@field show_label boolean
---@field filetypes table<string, boolean>

local M = {}

---@type VimSurfConfig
M.defaults = {
  enabled = true,
  api_url = "https://code-arena.fly.dev",
  model = "claude-3-5-sonnet-20241022",
  user_id = nil,
  username = nil,
  password = nil,
  max_tokens = 100,
  temperature = 0.2,
  debounce_ms = 200,
  show_label = true,
  filetypes = {
    help = false,
    gitcommit = false,
    gitrebase = false,
    [""] = false,
  },
}

---@type VimSurfConfig
M.options = vim.deepcopy(M.defaults)

---Setup configuration
---@param opts VimSurfConfig?
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

---Check if filetype is enabled
---@param ft string
---@return boolean
function M.is_filetype_enabled(ft)
  local disabled = M.options.filetypes[ft]
  if disabled == nil then
    return true
  end
  return not disabled
end

return M
