local config = require("vimsurf.config")
local completion = require("vimsurf.completion")
local render = require("vimsurf.render")
local commands = require("vimsurf.commands")
local utils = require("vimsurf.utils")

local M = {}

---Setup VimSurf
---@param opts VimSurfConfig?
function M.setup(opts)
  -- Setup configuration
  config.setup(opts)
  
  -- Setup highlights
  render.setup_highlights()
  
  -- Setup commands
  commands.setup_commands()
  
  -- Setup autocommands
  local group = vim.api.nvim_create_augroup("VimSurf", { clear = true })
  
  -- Trigger completion on text change in insert mode
  vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
    group = group,
    callback = function()
      completion.trigger()
    end,
  })
  
  -- REMOVED: InsertLeave autocmd (redundant with ModeChanged)
  -- The ModeChanged pattern "i:*" handles leaving insert mode
  
  -- Clear when leaving insert mode (any transition from insert)
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    pattern = "i*:*",  -- Any transition FROM insert mode
    callback = function()
      utils.debug("Left insert mode, clearing completions")
      completion.clear()
    end,
  })
  
  -- Re-setup highlights on colorscheme change
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      render.setup_highlights()
    end,
  })
  
  utils.debug("VimSurf initialized with Code-Arena backend")
end

-- Export API functions
M.accept = completion.accept
M.accept_word = completion.accept_word
M.accept_line = completion.accept_line
M.clear = completion.clear
M.cycle = completion.cycle
M.cycle_next = function() completion.cycle(1) end
M.cycle_prev = function() completion.cycle(-1) end

return M
