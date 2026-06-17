return {
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
