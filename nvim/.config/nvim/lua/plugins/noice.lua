-- Disabled: noice crashes nvim when pressing `:` on 0.11.x
-- See: https://github.com/folke/noice.nvim/issues
-- Re-enable when noice/nvim compatibility is fixed
return {
  { "folke/noice.nvim", enabled = false },
}
