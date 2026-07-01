-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Re-sign treesitter parsers after Lazy sync on macOS.
-- Downloaded parsers are built on Linux CI and lack valid macOS code signatures,
-- causing EXC_BAD_ACCESS (SIGKILL / Code Signature Invalid) on dlopen.
if vim.fn.has("mac") == 1 then
  vim.api.nvim_create_autocmd("User", {
    pattern = "LazySync",
    callback = function()
      local parser_dir = vim.fn.stdpath("data") .. "/site/parser"
      vim.fn.jobstart(
        { "find", parser_dir, "-name", "*.so", "-exec", "codesign", "--force", "--sign", "-", "{}", ";" },
        { detach = false }
      )
    end,
  })
end
