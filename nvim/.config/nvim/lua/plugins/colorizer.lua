return {
  "catgoose/nvim-colorizer.lua",
  event = "BufReadPre",
  opts = { -- set to setup table
    -- Filetype-specific settings
    css = {
      -- Enable all color formats
      RGB = true, -- #RGB
      RRGGBB = true, -- #RRGGBB
      RRGGBBAA = true, -- #RRGGBBAA
      rgb_fn = true, -- rgb(...)
      rgba_fn = true, -- rgba(...)
      hsl_fn = true, -- hsl(...)
      hsla_fn = true, -- hsla(...)
    },
    -- Optionally enable for other filetypes
    html = { RGB = true, RRGGBB = true, rgb_fn = true, hsl_fn = true },
    javascript = { RGB = true, RRGGBB = true, rgb_fn = true, hsl_fn = true },
  },
}
