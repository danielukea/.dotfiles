-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.winbar = "%=%m %f"
vim.api.nvim_create_user_command("CopyRelPath", "call setreg('+', expand('%'))", {})

-- Tree-sitter configuration
-- Disable tree-sitter for problematic file types if needed
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "vim", "help" },
  callback = function()
    vim.treesitter.stop()
  end,
})
