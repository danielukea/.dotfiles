return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        eruby = { "htmlbeautifier" },
        html = { "htmlbeautifier" },
        javascript = { "prettierd", "prettier" },
      },
    },
  },
}
