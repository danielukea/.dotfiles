return {
  "stevearc/oil.nvim",
  lazy = false,
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    -- Match LazyVim neo-tree global keybindings
    { "<leader>e", "<cmd>Oil<CR>", desc = "Explorer (Oil)" },
    { "<leader>E", function() require("oil").open(vim.uv.cwd()) end, desc = "Explorer cwd (Oil)" },
    { "<leader>fe", "<cmd>Oil<CR>", desc = "File Explorer (Oil)" },
    { "<leader>fE", function() require("oil").open(vim.uv.cwd()) end, desc = "File Explorer cwd (Oil)" },
    { "-", "<cmd>Oil<CR>", desc = "Open parent directory" },
  },
  opts = {
    default_file_explorer = true,
    columns = { "icon" },
    delete_to_trash = true,
    skip_confirm_for_simple_edits = true,
    watch_for_changes = true,
    view_options = {
      show_hidden = true, -- Match your neo-tree config
    },
    keymaps = {
      -- Neo-tree familiar navigation
      ["l"] = { "actions.select", desc = "Open" },
      ["h"] = { "actions.parent", desc = "Go to parent" },
      ["H"] = { "actions.toggle_hidden", desc = "Toggle hidden" },
      ["<CR>"] = { "actions.select", desc = "Open" },
      ["-"] = { "actions.parent", desc = "Go to parent" },

      -- Splits (match neo-tree/vim conventions)
      ["<C-s>"] = { "actions.select", opts = { vertical = true }, desc = "Open in vsplit" },
      ["<C-x>"] = { "actions.select", opts = { horizontal = true }, desc = "Open in split" },
      ["<C-t>"] = { "actions.select", opts = { tab = true }, desc = "Open in new tab" },

      -- Copy path to clipboard (Y like LazyVim neo-tree)
      ["Y"] = { "actions.copy_entry_path", desc = "Copy path" },

      -- Other useful mappings
      ["q"] = { "actions.close", desc = "Close" },
      ["<C-c>"] = { "actions.close", desc = "Close" },
      ["<C-l>"] = { "actions.refresh", desc = "Refresh" },
      ["<C-p>"] = { "actions.preview", desc = "Preview" },
      ["g."] = { "actions.toggle_hidden", desc = "Toggle hidden" },
      ["g?"] = { "actions.show_help", desc = "Show help" },
    },
  },
  config = function(_, opts)
    require("oil").setup(opts)

    -- Register which-key hints for oil buffers
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "oil",
      callback = function()
        local wk = require("which-key")
        wk.add({
          buffer = true,
          { "l", desc = "Open" },
          { "h", desc = "Go to parent" },
          { "H", desc = "Toggle hidden" },
          { "Y", desc = "Copy path" },
          { "q", desc = "Close" },
          { "<C-s>", desc = "Open in vsplit" },
          { "<C-x>", desc = "Open in split" },
          { "<C-t>", desc = "Open in new tab" },
          { "<C-p>", desc = "Preview" },
          { "<C-l>", desc = "Refresh" },
          { "g", group = "Oil actions" },
          { "g.", desc = "Toggle hidden" },
          { "g?", desc = "Show help" },
        })
      end,
    })
  end,
}
