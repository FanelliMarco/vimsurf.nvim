local api = require("vimsurf.api")
local config = require("vimsurf.config")
local render = require("vimsurf.render")
local utils = require("vimsurf.utils")

local M = {}

-- Completion state
M.state = {
  timer = vim.loop.new_timer(),
  completions = nil,
  current_index = 1,
  pair_id = nil,
  request_id = 0,
  pending = false,
  cursor_pos = nil,
  ignore_next_change = false,
  last_request_time = 0,
}

---Check if we're in insert mode
---@return boolean
local function is_insert_mode()
  local mode = vim.api.nvim_get_mode().mode
  return mode == "i" or mode == "ic" or mode == "ix"
end

---Check if completions should be shown
---@return boolean
function M.should_complete()
  if not config.options.enabled then
    return false
  end
  
  -- Check insert mode first
  if not is_insert_mode() then
    return false
  end
  
  -- FIXED: Actually use the ignore flag
  if M.state.ignore_next_change then
    utils.debug("Ignoring change event (post-acceptance)")
    M.state.ignore_next_change = false
    return false
  end
  
  local ft = vim.bo.filetype
  if not config.is_filetype_enabled(ft) then
    return false
  end
  
  if vim.bo.buftype ~= "" then
    return false
  end
  
  -- Rate limiting
  local now = vim.loop.now()
  if now - M.state.last_request_time < 500 then
    utils.debug("Rate limiting: too soon since last request")
    return false
  end
  
  return true
end

---Request completions from API
function M.request()
  if not M.should_complete() then
    return
  end
  
  M.state.request_id = M.state.request_id + 1
  M.state.last_request_time = vim.loop.now()
  local request_id = M.state.request_id
  
  M.state.pending = true
  
  local prefix, suffix = utils.get_context()
  local row, col = utils.get_cursor()
  M.state.cursor_pos = { row = row, col = col }
  
  utils.debug("Requesting completions (ID: " .. request_id .. ")")
  
  if config.options.show_label then
    render.show_label("🏄 surfing...", row)
  end
  
  api.get_completions(prefix, suffix, function(completions, pair_id)
    M.state.pending = false
    
    -- FIXED: Ignore responses when not in insert mode
    if not is_insert_mode() then
      utils.debug("Ignoring response (not in insert mode)")
      return
    end
    
    -- Ignore outdated requests
    if request_id ~= M.state.request_id then
      utils.debug("Ignoring outdated request " .. request_id)
      return
    end
    
    if completions and #completions > 0 then
      M.state.completions = completions
      M.state.current_index = 1
      M.state.pair_id = pair_id
      
      M.show_current()
      utils.debug("Received " .. #completions .. " completions")
    else
      M.state.completions = nil
      render.clear()
      utils.debug("No completions received")
    end
  end)
end

---Show current completion
function M.show_current()
  if not M.state.completions or #M.state.completions == 0 then
    return
  end
  
  -- FIXED: Double-check we're still in insert mode before rendering
  if not is_insert_mode() then
    utils.debug("Not showing completion (not in insert mode)")
    return
  end
  
  local completion = M.state.completions[M.state.current_index]
  local row = M.state.cursor_pos.row
  local col = M.state.cursor_pos.col
  
  render.show(completion.text, row, col)
  
  if config.options.show_label then
    local label = string.format(
      "🏄 %d/%d [%s]",
      M.state.current_index,
      #M.state.completions,
      completion.model
    )
    render.show_label(label, row)
  end
end

---Cycle to next/previous completion
---@param direction integer 1 for next, -1 for previous
function M.cycle(direction)
  if not M.state.completions or #M.state.completions <= 1 then
    return
  end
  
  direction = direction or 1
  M.state.current_index = M.state.current_index + direction
  
  if M.state.current_index > #M.state.completions then
    M.state.current_index = 1
  elseif M.state.current_index < 1 then
    M.state.current_index = #M.state.completions
  end
  
  M.show_current()
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

---Accept the current completion
function M.accept()
  if not M.state.completions or M.state.current_index > #M.state.completions then
    return
  end
  
  local completion = M.state.completions[M.state.current_index]
  local row, col = utils.get_cursor()
  
  -- Set flag to ignore next change
  M.state.ignore_next_change = true
  utils.debug("Set ignore_next_change flag")
  
  -- Insert completion
  local current_line = vim.api.nvim_get_current_line()
  local lines = vim.split(completion.text, "\n", { plain = true })
  
  if #lines == 1 then
    local new_line = current_line:sub(1, col) .. lines[1] .. current_line:sub(col + 1)
    utils.set_lines(row, row + 1, { new_line })
    utils.set_cursor(row, col + #lines[1])
  else
    lines[1] = current_line:sub(1, col) .. lines[1]
    lines[#lines] = lines[#lines] .. current_line:sub(col + 1)
    
    utils.set_lines(row, row + 1, lines)
    utils.set_cursor(row + #lines - 1, #lines[#lines] - #current_line:sub(col + 1))
  end
  
  -- Report outcome if enabled
  if config.options.report_outcomes and M.state.pair_id and #M.state.completions == 2 then
    local chosen = completion.completion_id
    local other_idx = M.state.current_index == 1 and 2 or 1
    local other = M.state.completions[other_idx].completion_id
    api.report_outcome(M.state.pair_id, chosen, other)
  end
  
  M.clear()
  
  if not config.options.silent then
    utils.info("Accepted: " .. completion.model)
  end
end

---Accept only one word
function M.accept_word()
  if not M.state.completions then
    return
  end
  
  local completion = M.state.completions[M.state.current_index]
  local row, col = utils.get_cursor()
  
  M.state.ignore_next_change = true
  utils.debug("Set ignore_next_change flag")
  
  local word = completion.text:match("^%S+") or ""
  
  if word ~= "" then
    local current_line = vim.api.nvim_get_current_line()
    local new_line = current_line:sub(1, col) .. word .. current_line:sub(col + 1)
    utils.set_lines(row, row + 1, { new_line })
    utils.set_cursor(row, col + #word)
  end
  
  M.clear()
end

---Accept only current line
function M.accept_line()
  if not M.state.completions then
    return
  end
  
  local completion = M.state.completions[M.state.current_index]
  local row, col = utils.get_cursor()
  
  M.state.ignore_next_change = true
  utils.debug("Set ignore_next_change flag")
  
  local first_line = completion.text:match("^[^\n]*") or ""
  
  if first_line ~= "" then
    local current_line = vim.api.nvim_get_current_line()
    local new_line = current_line:sub(1, col) .. first_line .. current_line:sub(col + 1)
    utils.set_lines(row, row + 1, { new_line })
    utils.set_cursor(row, col + #first_line)
  end
  
  M.clear()
end

---Clear completion
function M.clear()
  M.state.timer:stop()
  M.state.completions = nil
  M.state.current_index = 1
  M.state.pair_id = nil
  M.state.pending = false
  M.state.cursor_pos = nil
  render.clear()
end

return M
