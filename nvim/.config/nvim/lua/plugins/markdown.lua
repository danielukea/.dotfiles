return {
  {
    'mfussenegger/nvim-lint',
    optional = true,
    opts = {
      linters_by_ft = {
        markdown = {},
      },
    },
  },
  {
    'MeanderingProgrammer/render-markdown.nvim',
    opts = {
      heading = {
        sign = false,
        icons = { '󰲡 ', '󰲣 ', '󰲥 ', '󰲧 ', '󰲩 ', '󰲫 ' },
      },
      code = {
        sign = false,
        width = 'block',
        right_pad = 1,
      },
      checkbox = {
        enabled = true,
        unchecked = { icon = '󰄱 ' },
        checked   = { icon = '󰱒 ' },
      },
      bullet = {
        icons = { '●', '○', '◆', '◇' },
      },
    },
  },
}
