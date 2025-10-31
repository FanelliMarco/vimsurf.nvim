local config = require("vimsurf.config")
local utils = require("vimsurf.utils")

local M = {}

-- Namespace for extmarks
M.ns = vim.api.nvim_create_namespace("vimsurf")

-- Store extmark IDs
M.extmarks = {}

---Clear all virtual text
function M.clear()
  vim.api.nvim_buf_clear_namespace(0, M.ns, 0, -1)
  M.extmarks = {}
end

---Show completion as virtual text
---@param text string
---@param row integer (0-indexed)
---@param col integer
function M.show(text, row, col)
  M.clear()
  
  if utils.is_empty(text) then
    return
  end
  
  local lines = vim.split(text, "\n", { plain = true })
  
  -- First line as inline virtual text
  if #lines > 0 and lines[1] ~= "" then
    local id = vim.api.nvim_buf_set_extmark(0, M.ns, row, col, {
      virt_text = { { lines[1], "VimSurfSuggestion" } },
      virt_text_pos = "inline",
      hl_mode = "combine",
    })
    table.insert(M.extmarks, id)
  end
  
  -- Remaining lines as virtual lines
  if #lines > 1 then
    local virt_lines = {}
    for i = 2, #lines do
      if lines[i] ~= "" or i < #lines then
        table.insert(virt_lines, { { lines[i], "VimSurfSuggestion" } })
      end
    end
    
    if #virt_lines > 0 then
      local id = vim.api.nvim_buf_set_extmark(0, M.ns, row, 0, {
        virt_lines = virt_lines,
        virt_lines_above = false,
      })
      table.insert(M.extmarks, id)
    end
  end
end

---Show label (e.g., "completing...")
---@param text string
---@param row integer
function M.show_label(text, row)
  if not config.options.show_label then
    return
  end
  
  local id = vim.api.nvim_buf_set_extmark(0, M.ns, row, 0, {
    virt_text = { { text, "Comment" } },
    virt_text_pos = "right_align",
  })
  table.insert(M.extmarks, id)
end

---Initialize highlight groups
function M.setup_highlights()
  vim.api.nvim_set_hl(0, "VimSurfSuggestion", {
    fg = "#808080",
    italic = true,
    default = true,
  })
end

return M
