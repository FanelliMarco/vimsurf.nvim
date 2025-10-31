local config = require("vimsurf.config")
local utils = require("vimsurf.utils")
local curl = require("plenary.curl")

local M = {}

---Create pair and get completions from multiple models
---@param prefix string
---@param suffix string
---@param callback fun(completions: table[]?, pair_id: string?)
function M.get_completions(prefix, suffix, callback)
  local opts = config.options
  
  utils.debug("Requesting completions for prefix: " .. prefix:sub(-50))
  
  local body = vim.json.encode({
    prefix = prefix,
    suffix = suffix,
    userId = opts.user_id,
    privacy = opts.privacy,
  })
  
  curl.post(opts.api_url .. "/create_pair", {
    headers = {
      ["Content-Type"] = "application/json",
    },
    body = body,
    on_error = function(err)
      utils.error("API request failed: " .. vim.inspect(err))
      callback(nil, nil)
    end,
    callback = vim.schedule_wrap(function(response)
      if response.status == 200 then
        local ok, data = pcall(vim.json.decode, response.body)
        if ok and data.completionItems then
          local completions = {}
          for _, item in ipairs(data.completionItems) do
            table.insert(completions, {
              text = item.completion,
              model = item.model,
              completion_id = item.completionId,
              latency = item.latency,
              raw = item.raw_completion,
            })
          end
          utils.debug("Received " .. #completions .. " completions")
          callback(completions, data.pairId)
        else
          utils.error("Invalid response format: " .. vim.inspect(data))
          callback(nil, nil)
        end
      else
        utils.error("API error " .. response.status .. ": " .. (response.body or ""))
        callback(nil, nil)
      end
    end),
  })
end

---Report completion outcome (optional)
---@param pair_id string
---@param chosen_completion_id string
---@param other_completion_id string
function M.report_outcome(pair_id, chosen_completion_id, other_completion_id)
  if not config.options.report_outcomes then
    return
  end
  
  utils.debug("Reporting outcome for pair: " .. pair_id)
  
  curl.put(config.options.api_url .. "/add_completion_outcome", {
    headers = {
      ["Content-Type"] = "application/json",
    },
    body = vim.json.encode({
      pairId = pair_id,
      chosenCompletionId = chosen_completion_id,
      otherCompletionId = other_completion_id,
    }),
    callback = function(response)
      if response.status ~= 200 then
        utils.debug("Failed to report outcome: " .. response.status)
      end
    end,
  })
end

---List available models
---@param callback fun(models: string[]?)
function M.list_models(callback)
  utils.debug("Fetching available models")
  
  curl.get(config.options.api_url .. "/list_models", {
    callback = vim.schedule_wrap(function(response)
      if response.status == 200 then
        local ok, data = pcall(vim.json.decode, response.body)
        if ok and data.models then
          utils.debug("Found " .. #data.models .. " models")
          callback(data.models)
        else
          utils.error("Failed to parse models response")
          callback(nil)
        end
      else
        utils.error("Failed to fetch models: " .. response.status)
        callback(nil)
      end
    end),
  })
end

return M
