local config = require("vimsurf.config")
local utils = require("vimsurf.utils")
local curl = require("plenary.curl")

local M = {}

---Authenticate user
---@param callback fun(success: boolean)
function M.authenticate(callback)
  local opts = config.options
  
  if not (opts.user_id and opts.username and opts.password) then
    callback(true) -- No auth required
    return
  end
  
  utils.debug("Authenticating user: " .. opts.username)
  
  curl.post(opts.api_url .. "/users/authenticate", {
    headers = {
      ["Content-Type"] = "application/json",
    },
    body = vim.json.encode({
      userId = opts.user_id,
      username = opts.username,
      password = opts.password,
    }),
    callback = vim.schedule_wrap(function(response)
      if response.status == 200 then
        utils.debug("Authentication successful")
        callback(true)
      else
        utils.error("Authentication failed: " .. (response.body or "Unknown error"))
        callback(false)
      end
    end),
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

---Get completion using chat completions endpoint
---@param prefix string
---@param suffix string
---@param callback fun(completion: string?)
function M.get_completion(prefix, suffix, callback)
  local opts = config.options
  
  utils.debug("Requesting completion with model: " .. opts.model)
  
  -- Construct the prompt
  local prompt = string.format(
    "Complete this code. Return ONLY the completion text, no explanations or markdown:\n\n%s[CURSOR]%s",
    prefix,
    suffix
  )
  
  local messages = {
    {
      role = "system",
      content = "You are a code completion assistant. Provide only the code that should be inserted at [CURSOR]. No explanations, no markdown formatting, just the raw code."
    },
    {
      role = "user",
      content = prompt
    }
  }
  
  local body = vim.json.encode({
    model = opts.model,
    messages = messages,
    max_tokens = opts.max_tokens,
    temperature = opts.temperature,
    stream = false,
  })
  
  -- Try chat completions endpoint
  curl.post(opts.api_url .. "/v1/chat/completions", {
    headers = {
      ["Content-Type"] = "application/json",
    },
    body = body,
    on_error = function(err)
      utils.debug("Chat completions error: " .. vim.inspect(err))
      -- Fallback to FIM if chat completions fails
      M.get_fim_completion(prefix, suffix, callback)
    end,
    callback = vim.schedule_wrap(function(response)
      if response.status == 200 then
        local ok, data = pcall(vim.json.decode, response.body)
        if ok and data.choices and data.choices[1] then
          local completion = data.choices[1].message.content
          -- Clean up the completion
          completion = completion:gsub("^```%w*\n", ""):gsub("\n```$", "")
          utils.debug("Received completion: " .. completion:sub(1, 50) .. "...")
          callback(completion)
        else
          utils.error("Invalid completion response format")
          callback(nil)
        end
      else
        utils.debug("Chat completions failed with status: " .. response.status)
        -- Fallback to FIM
        M.get_fim_completion(prefix, suffix, callback)
      end
    end),
  })
end

---Get completion using FIM (Fill-In-Middle) endpoint
---@param prefix string
---@param suffix string
---@param callback fun(completion: string?)
function M.get_fim_completion(prefix, suffix, callback)
  local opts = config.options
  
  utils.debug("Requesting FIM completion")
  
  -- FIM format (might vary by model)
  local prompt = string.format("<fim_prefix>%s<fim_suffix>%s<fim_middle>", prefix, suffix)
  
  local body = vim.json.encode({
    model = opts.model,
    prompt = prompt,
    max_tokens = opts.max_tokens,
    temperature = opts.temperature,
    stop = { "<fim_suffix>", "<fim_middle>", "<|endoftext|>" },
  })
  
  curl.post(opts.api_url .. "/v1/completions", {
    headers = {
      ["Content-Type"] = "application/json",
    },
    body = body,
    on_error = function(err)
      utils.debug("FIM completions error: " .. vim.inspect(err))
      callback(nil)
    end,
    callback = vim.schedule_wrap(function(response)
      if response.status == 200 then
        local ok, data = pcall(vim.json.decode, response.body)
        if ok and data.choices and data.choices[1] then
          local completion = data.choices[1].text
          utils.debug("Received FIM completion: " .. completion:sub(1, 50) .. "...")
          callback(completion)
        else
          utils.error("Invalid FIM response format")
          callback(nil)
        end
      else
        utils.error("FIM completions failed: " .. response.status)
        callback(nil)
      end
    end),
  })
end

return M
