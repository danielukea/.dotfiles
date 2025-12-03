return {
  -- Jupytext: Auto-convert .ipynb to markdown
  {
    "GCBallesteros/jupytext.nvim",
    config = true,
  },

  -- Add Jupyter group to which-key
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>j", group = "Jupyter", icon = "󰠮" },
      },
    },
  },

  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    build = ":UpdateRemotePlugins",
    init = function()
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_auto_open_output = false
      vim.g.molten_wrap_output = true
      vim.g.molten_virt_text_output = true
      vim.g.molten_virt_lines_off_by_1 = true
    end,
    keys = {
      { "<leader>ji", ":MoltenInit<CR>", desc = "Initialize kernel" },
      { "<leader>je", ":MoltenEvaluateOperator<CR>", desc = "Evaluate operator" },
      { "<leader>jl", ":MoltenEvaluateLine<CR>", desc = "Evaluate line" },
      { "<leader>jc", "vip:<C-u>MoltenEvaluateVisual<CR>", desc = "Evaluate cell" },
      { "<leader>jv", ":<C-u>MoltenEvaluateVisual<CR>gv", mode = "v", desc = "Evaluate visual" },
      { "<leader>jr", ":MoltenReevaluateCell<CR>", desc = "Re-evaluate cell" },
      { "<leader>jR", ":MoltenReevaluateAll<CR>", desc = "Re-evaluate all" },
      { "<leader>jo", ":MoltenShowOutput<CR>", desc = "Show output" },
      { "<leader>jh", ":MoltenHideOutput<CR>", desc = "Hide output" },
      { "<leader>jd", ":MoltenDelete<CR>", desc = "Delete cell" },
      { "<leader>jx", ":MoltenInterrupt<CR>", desc = "Interrupt kernel" },
      { "<leader>jq", ":MoltenDeinit<CR>", desc = "Stop kernel" },
    },
  },
}
