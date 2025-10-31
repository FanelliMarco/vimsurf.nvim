local api = require("vimsurf.api")
local config = require("vimsurf.config")
local render = require("vimsurf.render")
local utils = require("vimsurf.utils")

local M = {}

-- Completion state
M.state = {
  timer = vim.loop.new_timer(),
  current = nil,  -- Current completion text
  request_id = 0, -- Request counter
  pending = false,
}

---Check if completions should be shown
---@return boolean
function M.should_complete()
  if not config.options.enabled then
    return false
  end
  
  local ft = vim.bo.filetype
  if not config.is_filetype_enabled(ft) then
    return false
  end
  
  -- Don't complete in special buffers
  if vim.bo.buftype ~= "" then
    return false
  end
  
  -- Must be in insert mode
  if vim.fn.mode() ~= "i" then
    return false
  end
  
  return true
end

---Request completion from API
function M.request()
  if not M.should_complete() then
    return
  end
  
  M.state.request_id = M.state.request_id + 1
  local request_id = M.state.request_id
  
  M.state.pending = true
  
  local prefix, suffix = utils.get_context()
  local row, col = utils.get_cursor()
  
  utils.debug("Requesting completion (ID: " .. request_id .. ")")
  
  if config.options.show_label then
    render.show_label("🏄 ...", row)
  end
  
  api.get_completion(prefix, suffix, function(completion)
    M.state.pending = false
    
    -- Ignore outdated requests
    if request_id ~= M.state.request_id then
      utils.debug("Ignoring outdated request " .. request_id)
      return
    end
    
    if completion and completion ~= "" then
      -- Store completion
      M.state.current = {
        text = completion,
        row = row,
        col = col,
      }
      
      -- Render it
      render.show(completion, row, col)
      utils.debug("Completion displayed")
    else
      M.state.current = nil
      render.clear()
      utils.debug("No completion received")
    end
  end)
end

---Trigger completion with debounce
function M.trigger()
  if not M.should_complete() then
    M.clear()
    return
  end
  
  M.state.timer:stop()
  
  M.state.timer:start(
    config.options.debounce_ms,
    0,
    vim.schedule_wrap(function()
      M.request()
    end)
  )
end

---Accept the full completion
function M.accept()
  if not M.state.current then
    return
  end
  
  local completion = M.state.current
  local row, col = utils.get_cursor()
  
  -- Insert completion
  local current_line = vim.api.nvim_get_current_line()
  local lines = vim.split(completion.text, "\n", { plain = true })
  
  if #lines == 1 then
    -- Single line
    local new_line = current_line:sub(1, col) .. lines[1] .. current_line:sub(col + 1)
    utils.set_lines(row, row + 1, { new_line })
    utils.set_cursor(row, col + #lines[1])
  else
    -- Multi-line
    lines[1] = current_line:sub(1, col) .. lines[1]
    lines[#lines] = lines[#lines] .. current_line:sub(col + 1)
    
    utils.set_lines(row, row + 1, lines)
    utils.set_cursor(row + #lines - 1, #lines[#lines] - #current_line:sub(col + 1))
  end
  
  M.clear()
  utils.debug("Completion accepted")
end

---Accept only one word
function M.accept_word()
  if not M.state.current then
    return
  end
  
  local completion = M.state.current
  local row, col = utils.get_cursor()
  
  -- Extract first word
  local word = completion.text:match("^%S+") or ""
  
  if word ~= "" then
    local current_line = vim.api.nvim_get_current_line()
    local new_line = current_line:sub(1, col) .. word .. current_line:sub(col + 1)
    utils.set_lines(row, row + 1, { new_line })
    utils.set_cursor(row, col + #word)
  end
  
  M.clear()
  utils.debug("Word accepted")
end

---Accept only current line
function M.accept_line()
  if not M.state.current then
    return
  end
  
  local completion = M.state.current
  local row, col = utils.get_cursor()
  
  -- Extract first line
  local first_line = completion.text:match("^[^\n]*") or ""
  
  if first_line ~= "" then
    local current_line = vim.api.nvim_get_current_line()
    local new_line = current_line:sub(1, col) .. first_line .. current_line:sub(col + 1)
    utils.set_lines(row, row + 1, { new_line })
    utils.set_cursor(row, col + #first_line)
  end
  
  M.clear()
  utils.debug("Line accepted")
end

---Clear completion
function M.clear()
  M.state.timer:stop()
  M.state.current = nil
  M.state.pending = false
  render.clear()
end

return M
