local M = {}

---@class VimSurfConfig
---@field enabled boolean
---@field api_url string
---@field user_id string
---@field privacy "Private"|"Debug"|"Research"
---@field max_tokens integer
---@field temperature number
---@field debounce_ms integer
---@field show_label boolean
---@field silent boolean
---@field max_retries integer
---@field cycle_on_complete boolean
---@field report_outcomes boolean
---@field filetypes table<string, boolean>

---@type VimSurfConfig
M.defaults = {
  enabled = true,
  api_url = "https://code-arena.fly.dev",
  user_id = "vimsurf-user",
  privacy = "Debug",
  max_tokens = 100,
  temperature = 0.2,
  debounce_ms = 300,  -- Increased from 200ms
  show_label = true,
  silent = false,     -- NEW: Don't spam error messages
  max_retries = 2,    -- NEW: Retry 500 errors
  cycle_on_complete = true,
  report_outcomes = false,
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
  
  -- Validate privacy
  local valid_privacy = { Private = true, Debug = true, Research = true }
  if not valid_privacy[M.options.privacy] then
    vim.notify(
      "VimSurf: Invalid privacy value. Using 'Debug'. Valid: Private, Debug, Research",
      vim.log.levels.WARN
    )
    M.options.privacy = "Debug"
  end
  
  -- Warn about Debug mode
  if M.options.privacy == "Debug" and not M.options.silent then
    vim.notify(
      "VimSurf: Using 'Debug' privacy mode (may be rate-limited). Consider 'Private' or 'Research'.",
      vim.log.levels.INFO
    )
  end
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
