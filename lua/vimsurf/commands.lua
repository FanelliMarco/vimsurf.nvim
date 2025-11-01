local api = require("vimsurf.api")
local config = require("vimsurf.config")
local completion = require("vimsurf.completion")
local utils = require("vimsurf.utils")

local M = {}

---List available models
function M.list_models()
  api.list_models(function(models)
    if models then
      local model_list = table.concat(models, "\n  • ")
      utils.info("Available models:\n  • " .. model_list)
    else
      utils.error("Failed to fetch models")
    end
  end)
end

---Enable completions
function M.enable()
  config.options.enabled = true
  utils.info("Enabled")
end

---Disable completions
function M.disable()
  config.options.enabled = false
  completion.clear()
  utils.info("Disabled")
end

---Toggle completions
function M.toggle()
  if config.options.enabled then
    M.disable()
  else
    M.enable()
  end
end

---Show status
function M.status()
  local status = config.options.enabled and "enabled" or "disabled"
  local stats = api.get_stats()
  
  local success_rate = 0
  if stats.total_requests > 0 then
    success_rate = math.floor((stats.success_count / stats.total_requests) * 100)
  end
  
  utils.info(string.format(
    "Status: %s\nUser ID: %s\nPrivacy: %s\nAPI: %s\nRequests: %d (Success: %d%%, Errors: %d)",
    status,
    config.options.user_id,
    config.options.privacy,
    config.options.api_url,
    stats.total_requests,
    success_rate,
    stats.error_500_count
  ))
end

---Cycle to next completion
function M.cycle_next()
  completion.cycle(1)
end

---Cycle to previous completion
function M.cycle_prev()
  completion.cycle(-1)
end

---Setup user commands
function M.setup_commands()
  vim.api.nvim_create_user_command("VimSurf", function(opts)
    local args = vim.split(opts.args, "%s+")
    local cmd = args[1]
    
    if cmd == "list_models" then
      M.list_models()
    elseif cmd == "enable" then
      M.enable()
    elseif cmd == "disable" then
      M.disable()
    elseif cmd == "toggle" then
      M.toggle()
    elseif cmd == "status" then
      M.status()
    elseif cmd == "next" then
      M.cycle_next()
    elseif cmd == "prev" then
      M.cycle_prev()
    else
      utils.error("Unknown command: " .. cmd)
      utils.info("Available: list_models, enable, disable, toggle, status, next, prev")
    end
  end, {
    nargs = 1,
    complete = function()
      return { "list_models", "enable", "disable", "toggle", "status", "next", "prev" }
    end,
  })
end

return M
