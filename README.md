# VimSurf

<div align="center">

**⚡ AI-powered code completion for Neovim using CodeArena models ⚡**

[![Neovim](https://img.shields.io/badge/Neovim-0.10+-green.svg?style=flat-square&logo=Neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1+-blue.svg?style=flat-square&logo=lua)](https://www.lua.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

A lightweight, asynchronous code completion plugin for Neovim that leverages CodeArena's powerful AI models including Claude, GPT-4, Gemini, and DeepSeek Coder.

[Features](#-features) • [Installation](#-installation) • [Configuration](#%EF%B8%8F-configuration) • [Usage](#-usage) • [Commands](#-commands)

</div>

---

## ✨ Features

- 🤖 **Multiple AI Models** - Support for 14+ models including Claude 3.5 Sonnet, GPT-4o, Gemini 2.0, DeepSeek Coder, and more
- ⚡ **Async Completions** - Non-blocking completion requests that won't freeze your editor
- 🎯 **Context-Aware** - Provides completions based on surrounding code context
- 💬 **Virtual Text Display** - Suggestions appear as ghost text at your cursor
- 🔄 **Multi-line Support** - Handle both single-line and multi-line completions
- 🎨 **Customizable** - Extensive configuration options for behavior and appearance
- 🪶 **Lightweight** - Minimal dependencies and resource usage
- 🔧 **Filetype Filtering** - Enable/disable for specific file types
- ⌨️ **Flexible Keybinds** - No default mappings, configure your own workflow

## 📋 Requirements

- Neovim >= **0.10.0**
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- curl (for API requests)
- CodeArena account (optional, depending on API requirements)

## 📦 Installation

### 💤 [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "yourusername/vimsurf",
  dependencies = { "nvim-lua/plenary.nvim" },
  event = "InsertEnter",
  config = function()
    -- Optional: Enable debug mode
    -- vim.g.vimsurf_debug = true
    
    require("vimsurf").setup({
      -- IMPORTANT: Use a unique user_id (not "test-user-123")
      user_id = "your-unique-id-here",  -- Change this!
      
      -- Try "Private" or "Research" if Debug is too rate-limited
      privacy = "Private",  -- "Private", "Debug", or "Research"
      
      -- Don't spam errors (Code-Arena is flaky)
      silent = true,
      
      -- Retry 500 errors automatically
      max_retries = 2,
      
      -- Longer debounce to reduce request frequency
      debounce_ms = 400,
    })
    
    -- Keymaps
    vim.keymap.set("i", "<C-g>", function()
      require("vimsurf").accept()
    end, { desc = "VimSurf: Accept" })
    
    vim.keymap.set("i", "<C-n>", function()
      require("vimsurf").cycle_next()
    end, { desc = "VimSurf: Next model" })
    
    vim.keymap.set("i", "<C-p>", function()
      require("vimsurf").cycle_prev()
    end, { desc = "VimSurf: Prev model" })
  end,
}
```
### Check Success Rate
Vim
```vim
:VimSurf status
```
Shows:
```text

Status: enabled
User ID: your-id
Privacy: Private
Requests: 50 (Success: 65%, Errors: 17)
```
