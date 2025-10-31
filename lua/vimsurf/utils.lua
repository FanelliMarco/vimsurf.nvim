local M = {}

---Check if value is empty
---@param val any
---@return boolean
function M.is_empty(val)
  if val == nil then
    return true
  end
  if type(val) == "string" then
    return val == ""
  end
  if type(val) == "table" then
    return vim.tbl_isempty(val)
  end
  return false
end

---Get current cursor position (0-indexed)
---@return integer row, integer col
function M.get_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return cursor[1] - 1, cursor[2]
end

---Set cursor position (0-indexed)
---@param row integer
---@param col integer
function M.set_cursor(row, col)
  vim.api.nvim_win_set_cursor(0, { row + 1, col })
end

---Get lines from buffer
---@param start_row integer (0-indexed)
---@param end_row integer (0-indexed)
---@return string[]
function M.get_lines(start_row, end_row)
  return vim.api.nvim_buf_get_lines(0, start_row, end_row, false)
end

---Set lines in buffer
---@param start_row integer (0-indexed)
---@param end_row integer (0-indexed)
---@param lines string[]
function M.set_lines(start_row, end_row, lines)
  vim.api.nvim_buf_set_lines(0, start_row, end_row, false, lines)
end

---Get context around cursor for completion
---@param context_lines integer Number of lines before/after cursor
---@return string prefix, string suffix
function M.get_context(context_lines)
  context_lines = context_lines or 20
  
  local row, col = M.get_cursor()
  local total_lines = vim.api.nvim_buf_line_count(0)
  
  -- Get lines before cursor
  local start_row = math.max(0, row - context_lines)
  local lines_before = M.get_lines(start_row, row)
  
  -- Get current line
  local current_line = vim.api.nvim_get_current_line()
  
  -- Get lines after cursor
  local end_row = math.min(total_lines, row + 1 + context_lines)
  local lines_after = M.get_lines(row + 1, end_row)
  
  -- Build prefix (everything before cursor)
  local prefix_lines = vim.deepcopy(lines_before)
  table.insert(prefix_lines, current_line:sub(1, col))
  local prefix = table.concat(prefix_lines, "\n")
  
  -- Build suffix (everything after cursor)
  local suffix_lines = { current_line:sub(col + 1) }
  vim.list_extend(suffix_lines, lines_after)
  local suffix = table.concat(suffix_lines, "\n")
  
  return prefix, suffix
end

---Notify user
---@param msg string
---@param level integer?
function M.notify(msg, level)
  level = level or vim.log.levels.INFO
  vim.notify("VimSurf: " .. msg, level)
end

---Notify error
---@param msg string
function M.error(msg)
  M.notify(msg, vim.log.levels.ERROR)
end

---Notify warning
---@param msg string
function M.warn(msg)
  M.notify(msg, vim.log.levels.WARN)
end

---Notify info
---@param msg string
function M.info(msg)
  M.notify(msg, vim.log.levels.INFO)
end

---Debug log
---@param msg string
function M.debug(msg)
  if vim.g.vimsurf_debug then
    vim.notify("VimSurf [DEBUG]: " .. msg, vim.log.levels.DEBUG)
  end
end

return M
