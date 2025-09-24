--[[
Devcontainer Clipboard Plugin

Why this exists:
- Devcontainers isolate clipboard from host system by default
- Standard clipboard tools (pbcopy/pbpaste) don't work inside containers
- OSC52 escape sequences can tunnel clipboard through terminal/tmux to host
- Without this, copy/paste between container and host requires manual workarounds

This plugin auto-detects devcontainer environments and configures OSC52
clipboard forwarding so normal vim yank/paste operations work seamlessly
with the host system clipboard through tmux.
--]]

return {
  -- OSC52 clipboard plugin - always load, configure based on environment
  {
    "ojroques/nvim-osc52",
    lazy = false,
    config = function()
      local is_devcontainer = vim.fn.filereadable("/.dockerenv") == 1 or vim.env.DEVCONTAINER == "true"

      if is_devcontainer then
        require("osc52").setup({
          max_length = 0, -- Maximum length of selection (0 for no limit)
          silent = false, -- Disable message on successful copy
          trim = false, -- Trim text before copy
          tmux_passthrough = true, -- Enable tmux passthrough for OSC52
        })

        -- Set up clipboard integration with proper function calls
        local osc52 = require("osc52")
        vim.g.clipboard = {
          name = "osc52",
          copy = {
            ["+"] = function(lines, regtype)
              osc52.copy(table.concat(lines, "\n"))
            end,
            ["*"] = function(lines, regtype)
              osc52.copy(table.concat(lines, "\n"))
            end,
          },
          paste = {
            ["+"] = function()
              return vim.fn.split(vim.fn.getreg("+"), "\n"), vim.fn.getregtype("+")
            end,
            ["*"] = function()
              return vim.fn.split(vim.fn.getreg("*"), "\n"), vim.fn.getregtype("*")
            end,
          },
        }

        -- Enable system clipboard integration
        vim.opt.clipboard = "unnamedplus"

        -- Auto-copy visual selections to system clipboard
        vim.api.nvim_create_autocmd("TextYankPost", {
          group = vim.api.nvim_create_augroup("DevcontainerOSC52", { clear = true }),
          callback = function()
            if vim.v.event.operator == "y" and vim.v.event.regname == "+" then
              require("osc52").copy_register("+")
            end
          end,
        })
      else
        -- Just set up basic OSC52 without overriding system clipboard
        require("osc52").setup()
      end
    end,
  },
}