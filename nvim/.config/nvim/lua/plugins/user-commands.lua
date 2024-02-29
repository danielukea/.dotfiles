vim.api.nvim_create_user_command("CopyRelPath", "call setreg('+', expand('%'))", {})
