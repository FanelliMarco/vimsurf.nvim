local config = require("vimsurf.config")
local utils = require("vimsurf.utils")
local curl = require("plenary.curl")

local M = {}

-- Track 500 errors for statistics
local error_stats = {
  total_requests = 0,
  error_500_count = 0,
  success_count = 0,
}

---Create pair and get completions from multiple models
---@param prefix string
---@param suffix string
---@param callback fun(completions: table[]?, pair_id: string?)
---@param retry_count? integer
function M.get_completions(prefix, suffix, callback, retry_count)
  retry_count = retry_count or 0
  local opts = config.options
  
  error_stats.total_requests = error_stats.total_requests + 1
  
  utils.debug("=== VimSurf API Request ===")
  utils.debug("Endpoint: " .. opts.api_url .. "/create_pair")
  utils.debug("Prefix length: " .. #prefix)
  utils.debug("Suffix length: " .. #suffix)
  utils.debug("Retry attempt: " .. retry_count)
  
  -- Build request body
  local request_body = {
    prefix = prefix,
    userId = opts.user_id,
    privacy = opts.privacy,
  }
  
  -- Only add suffix if not empty (match successful curl format)
  if suffix and suffix ~= "" then
    request_body.suffix = suffix
  end
  
  local body = vim.json.encode(request_body)
  utils.debug("Request body: " .. body)
  
  curl.post(opts.api_url .. "/create_pair", {
    headers = {
      ["Content-Type"] = "application/json",
    },
    body = body,
    on_error = function(err)
      utils.error("=== VimSurf API Error (on_error) ===")
      utils.error("Error details: " .. vim.inspect(err))
      callback(nil, nil)
    end,
    callback = vim.schedule_wrap(function(response)
      utils.debug("=== VimSurf API Response ===")
      utils.debug("Status: " .. tostring(response.status))
      
      if response.status == 200 then
        error_stats.success_count = error_stats.success_count + 1
        
        utils.debug("Response body: " .. (response.body or "nil"))
        local ok, data = pcall(vim.json.decode, response.body)
        
        if not ok then
          utils.error("JSON decode failed: " .. tostring(data))
          callback(nil, nil)
          return
        end
        
        if not data.completionItems then
          utils.error("No completionItems in response")
          callback(nil, nil)
          return
        end
        
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
        
        utils.debug("Parsed " .. #completions .. " completions successfully")
        
        -- Show success rate periodically
        if error_stats.total_requests % 10 == 0 then
          local success_rate = math.floor(
            (error_stats.success_count / error_stats.total_requests) * 100
          )
          utils.debug(string.format(
            "Stats: %d requests, %d success (%d%%), %d errors (500)",
            error_stats.total_requests,
            error_stats.success_count,
            success_rate,
            error_stats.error_500_count
          ))
        end
        
        callback(completions, data.pairId)
        
      elseif response.status == 500 then
        error_stats.error_500_count = error_stats.error_500_count + 1
        
        -- Retry logic for 500 errors (Code-Arena is flaky)
        if retry_count < config.options.max_retries then
          utils.debug(string.format(
            "Got 500 error, retrying (%d/%d)...",
            retry_count + 1,
            config.options.max_retries
          ))
          
          -- Exponential backoff: 100ms, 200ms, 400ms
          local delay = 100 * (2 ^ retry_count)
          
          vim.defer_fn(function()
            M.get_completions(prefix, suffix, callback, retry_count + 1)
          end, delay)
        else
          -- Only show error if all retries failed
          if not config.options.silent then
            utils.warn(string.format(
              "API temporarily unavailable (500 error after %d retries). Success rate: %d%%",
              config.options.max_retries,
              math.floor((error_stats.success_count / error_stats.total_requests) * 100)
            ))
          end
          utils.debug("API error 500 after max retries: " .. (response.body or ""))
          callback(nil, nil)
        end
        
      else
        utils.error("=== VimSurf API Failed ===")
        utils.error("Status code: " .. tostring(response.status))
        utils.error("Response body: " .. (response.body or "empty"))
        
        if response.body then
          local ok, error_data = pcall(vim.json.decode, response.body)
          if ok and error_data.detail then
            utils.error("Server error: " .. error_data.detail)
          end
        end
        
        callback(nil, nil)
      end
    end),
  })
end

---List available models
---@param callback fun(models: string[]?)
function M.list_models(callback)
  utils.debug("Fetching models from: " .. config.options.api_url .. "/list_models")
  
  curl.get(config.options.api_url .. "/list_models", {
    on_error = function(err)
      utils.error("Failed to fetch models: " .. vim.inspect(err))
      callback(nil)
    end,
    callback = vim.schedule_wrap(function(response)
      if response.status == 200 then
        local ok, data = pcall(vim.json.decode, response.body)
        if ok and data.models then
          callback(data.models)
        else
          callback(nil)
        end
      else
        utils.error("Models request failed: " .. response.status)
        callback(nil)
      end
    end),
  })
end

---Report completion outcome
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
      if response.status == 200 then
        utils.debug("Outcome reported successfully")
      else
        utils.debug("Outcome report failed: " .. response.status)
      end
    end,
  })
end

---Get error statistics
---@return table
function M.get_stats()
  return error_stats
end

return M
