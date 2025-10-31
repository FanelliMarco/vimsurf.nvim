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
  utils.info(string.format(
    "Status: %s\nModel: %s\nAPI: %s",
    status,
    config.options.model,
    config.options.api_url
  ))
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
    else
      utils.error("Unknown command: " .. cmd)
      utils.info("Available commands: list_models, enable, disable, toggle, status")
    end
  end, {
    nargs = 1,
    complete = function()
      return { "list_models", "enable", "disable", "toggle", "status" }
    end,
  })
end

return M
