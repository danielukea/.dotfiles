return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ruby_lsp = {
          mason = false,
          cmd = { "ruby-lsp" },
          init_options = {
            formatter = "auto",
            linters = {},
          },
        },
      },
    },
  },
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        -- Remove ruby-lsp from Mason's automatic installation
        -- "ruby-lsp", -- Commented out to prevent Mason from managing it
      },
    },
  },
}
