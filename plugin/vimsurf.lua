-- Prevent loading twice
if vim.g.loaded_vimsurf then
  return
end
vim.g.loaded_vimsurf = 1

-- Auto-setup with defaults if user doesn't call setup()
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    if not vim.g.vimsurf_setup_called then
      -- User didn't call setup(), use defaults
      -- This allows the plugin to work without explicit setup()
    end
  end,
})
