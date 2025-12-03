return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    log_level = "debug",
    enable_diagnostics = true,
    enable_git_status = true,
    filesystem = {
      filtered_items = {
        visible = true, -- Show hidden files by default
        hide_dotfiles = false,
        hide_gitignored = false,
      },
    },
  },
}
