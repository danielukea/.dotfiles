-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.winbar = "%=%m %f"
vim.api.nvim_create_user_command("CopyRelPath", "call setreg('+', expand('%'))", {})

vim.g.lazyvim_python_lsp = "pyright"
