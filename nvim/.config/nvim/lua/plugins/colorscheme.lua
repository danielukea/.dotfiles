return {
  {
    "AlexvZyl/nordic.nvim",
    config = function()
      require("nordic").setup({
        transparent_bg = true,
      })
      require("notify").setup({
        background_colour = "#000000",
      })
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      transparent = true,
      colorscheme = "nordic",
    },
  },
}
