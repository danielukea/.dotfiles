return {
  "obsidian-nvim/obsidian.nvim",
  version = "*", -- recommended, use latest release instead of latest commit
  event = {
    "BufReadPre " .. vim.fn.expand("~") .. "/Documents/Wealthbox/*.md",
    "BufNewFile " .. vim.fn.expand("~") .. "/Documents/Wealthbox/*.md",
  },
  opts = {
    workspaces = {
      {
        name = "work",
        path = "~/Documents/Wealthbox/",
      },
    },
    ui = { enable = true },
  },
}
