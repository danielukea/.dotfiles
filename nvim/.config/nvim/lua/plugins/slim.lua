return {
  {
    "slim-template/vim-slim",
    ft = { "slim", "slimlesbars" },
    config = function()
      -- Associate .html.slim files with slim filetype
      vim.filetype.add({
        extension = {
          slim = "slim",
        },
        pattern = {
          [".*%.html%.slim"] = "slim",
        },
      })
    end,
  },
}
