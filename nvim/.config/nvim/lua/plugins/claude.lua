--[[
Claude Code Tmux Integration

Sends buffer file paths and visual selections to Claude Code running in a tmux pane.
Uses @/path/to/file syntax for file references that Claude Code understands natively.

Usage:
  <leader>ccf - Send current file path as @/path/to/file
  <leader>ccs - Send visual selection as text (visual mode)
  <leader>ccq - Show queue of sent files
  <leader>ccx - Clear the queue

Commands:
  :ClaudeSetPane %N  - Manually set Claude pane ID
  :ClaudeClearCache  - Force re-discovery of Claude pane
--]]

return {
  -- which-key group registration
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>cc", group = "Claude Code", icon = "" },
      },
    },
  },

  -- Claude Code tmux integration
  {
    name = "claude-tmux",
    dir = vim.fn.stdpath("config"),
    lazy = false,
    keys = {
      { "<leader>ccf", desc = "Send file to Claude" },
      { "<leader>ccs", mode = "v", desc = "Send selection to Claude" },
      { "<leader>ccq", desc = "Show Claude queue" },
      { "<leader>ccx", desc = "Clear Claude queue" },
    },
    config = function()
      -- Module state
      local M = {
        config = {
          pane_cache_duration = 30, -- seconds
          target_title_pattern = "✳", -- Claude Code panes have this in their title
        },
        state = {
          cached_pane_id = nil,
          cache_time = 0,
          queued_items = {},
        },
      }

      -- Notification helpers
      local function notify(msg, level)
        vim.notify(msg, level or vim.log.levels.INFO, { title = "Claude Code" })
      end

      local function notify_error(msg)
        notify(msg, vim.log.levels.ERROR)
      end

      local function notify_success(msg)
        notify(msg, vim.log.levels.INFO)
      end

      local function notify_warn(msg)
        notify(msg, vim.log.levels.WARN)
      end

      -- Check if running inside tmux
      local function is_in_tmux()
        return vim.env.TMUX ~= nil and vim.env.TMUX ~= ""
      end

      -- Find the tmux pane running Claude Code
      local function find_claude_pane()
        -- Check cache first
        local now = os.time()
        if M.state.cached_pane_id and (now - M.state.cache_time) < M.config.pane_cache_duration then
          return M.state.cached_pane_id
        end

        -- Helper to find Claude pane in output
        local function find_in_output(output)
          for line in output:gmatch("[^\r\n]+") do
            local pane_id, title = line:match("^(%%%d+):(.*)$")
            if pane_id and title then
              if title:find(M.config.target_title_pattern, 1, true) then
                return pane_id
              end
            end
          end
          return nil
        end

        -- First, try current window only (most likely target)
        local cmd = "tmux list-panes -F '#{pane_id}:#{pane_title}'"
        local output = vim.fn.system(cmd)

        if vim.v.shell_error == 0 then
          local claude_pane = find_in_output(output)
          if claude_pane then
            M.state.cached_pane_id = claude_pane
            M.state.cache_time = now
            return claude_pane
          end
        end

        -- Fall back to all panes in session
        cmd = "tmux list-panes -s -F '#{pane_id}:#{pane_title}'"
        output = vim.fn.system(cmd)

        if vim.v.shell_error ~= 0 then
          return nil, "Failed to list tmux panes"
        end

        local claude_pane = find_in_output(output)
        if not claude_pane then
          return nil, "Claude Code pane not found. Start Claude Code in a tmux pane."
        end

        -- Cache the result
        M.state.cached_pane_id = claude_pane
        M.state.cache_time = now

        return claude_pane
      end

      -- Send text to tmux pane (without pressing Enter - user queues multiple items)
      local function send_to_tmux(pane_id, text)
        -- Escape single quotes for shell
        local escaped_text = text:gsub("'", "'\\''")
        -- Use -l for literal mode (preserves special characters)
        local cmd = string.format("tmux send-keys -t %s -l '%s'", pane_id, escaped_text)
        vim.fn.system(cmd)

        if vim.v.shell_error ~= 0 then
          return false, "Failed to send to tmux pane"
        end

        return true
      end

      -- Send current file to Claude Code
      function M.send_file()
        if not is_in_tmux() then
          notify_error("Not running in tmux. Start tmux to use Claude Code integration.")
          return
        end

        local filepath = vim.fn.expand("%:p")
        if filepath == "" or filepath == "." then
          notify_error("No file in current buffer")
          return
        end

        -- Check if file exists
        if vim.fn.filereadable(filepath) == 0 then
          notify_warn("File not saved to disk: " .. vim.fn.fnamemodify(filepath, ":t"))
        end

        local pane_id, err = find_claude_pane()
        if not pane_id then
          notify_error(err or "Could not find Claude Code pane")
          return
        end

        -- Format as @/path/to/file with trailing space for next item
        local claude_ref = "@" .. filepath .. " "
        local success, send_err = send_to_tmux(pane_id, claude_ref)

        if not success then
          notify_error(send_err or "Failed to send to Claude Code")
          return
        end

        -- Track queued item
        table.insert(M.state.queued_items, {
          type = "file",
          path = filepath,
          display = vim.fn.fnamemodify(filepath, ":~:."),
          time = os.time(),
        })

        notify_success("Queued: " .. vim.fn.fnamemodify(filepath, ":~:."))
      end

      -- Send visual selection to Claude Code
      function M.send_selection()
        if not is_in_tmux() then
          notify_error("Not running in tmux. Start tmux to use Claude Code integration.")
          return
        end

        -- Get visual selection marks
        local start_pos = vim.fn.getpos("'<")
        local end_pos = vim.fn.getpos("'>")
        local start_line = start_pos[2]
        local end_line = end_pos[2]
        local start_col = start_pos[3]
        local end_col = end_pos[3]

        if start_line == 0 or end_line == 0 then
          notify_error("No visual selection")
          return
        end

        -- Get the selected lines
        local lines = vim.fn.getline(start_line, end_line)
        if type(lines) == "string" then
          lines = { lines }
        end

        if #lines == 0 or (#lines == 1 and lines[1] == "") then
          notify_error("Empty selection")
          return
        end

        -- Handle selection mode bounds
        local mode = vim.fn.visualmode()
        if mode == "v" then
          -- Character-wise: trim first and last lines
          if #lines == 1 then
            lines[1] = lines[1]:sub(start_col, end_col)
          else
            lines[1] = lines[1]:sub(start_col)
            lines[#lines] = lines[#lines]:sub(1, end_col)
          end
        elseif mode == "\22" then
          -- Block-wise (Ctrl-V): trim each line to selected columns
          for i = 1, #lines do
            lines[i] = lines[i]:sub(start_col, end_col)
          end
        end
        -- Line-wise (V) sends full lines as-is

        local selection_text = table.concat(lines, "\n")

        local pane_id, err = find_claude_pane()
        if not pane_id then
          notify_error(err or "Could not find Claude Code pane")
          return
        end

        -- Add trailing space for next item
        local success, send_err = send_to_tmux(pane_id, selection_text .. " ")

        if not success then
          notify_error(send_err or "Failed to send to Claude Code")
          return
        end

        -- Track queued item
        local preview = selection_text:sub(1, 40):gsub("\n", "↵")
        if #selection_text > 40 then
          preview = preview .. "..."
        end

        table.insert(M.state.queued_items, {
          type = "selection",
          preview = preview,
          line_count = #lines,
          time = os.time(),
        })

        notify_success(string.format("Queued: %d line%s", #lines, #lines > 1 and "s" or ""))
      end

      -- Show queued items
      function M.show_queue()
        if #M.state.queued_items == 0 then
          notify("Queue is empty", vim.log.levels.INFO)
          return
        end

        local lines = { "Claude Code Queue:" }
        for i, item in ipairs(M.state.queued_items) do
          if item.type == "file" then
            table.insert(lines, string.format("  %d. [file] %s", i, item.display))
          else
            table.insert(lines, string.format("  %d. [selection] %s", i, item.preview))
          end
        end

        notify(table.concat(lines, "\n"), vim.log.levels.INFO)
      end

      -- Clear queue
      function M.clear_queue()
        local count = #M.state.queued_items
        M.state.queued_items = {}
        if count > 0 then
          notify_success(string.format("Cleared %d item%s from queue", count, count ~= 1 and "s" or ""))
        else
          notify("Queue was already empty", vim.log.levels.INFO)
        end
      end

      -- Register keymaps
      vim.keymap.set("n", "<leader>ccf", M.send_file, {
        desc = "Send file to Claude",
        noremap = true,
        silent = true,
      })

      vim.keymap.set("v", "<leader>ccs", function()
        -- Exit visual mode first to set '< and '> marks
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
        -- Small delay to ensure marks are set
        vim.schedule(function()
          M.send_selection()
        end)
      end, {
        desc = "Send selection to Claude",
        noremap = true,
        silent = true,
      })

      vim.keymap.set("n", "<leader>ccq", M.show_queue, {
        desc = "Show Claude queue",
        noremap = true,
        silent = true,
      })

      vim.keymap.set("n", "<leader>ccx", M.clear_queue, {
        desc = "Clear Claude queue",
        noremap = true,
        silent = true,
      })

      -- User commands for manual control
      vim.api.nvim_create_user_command("ClaudeSetPane", function(opts)
        -- Validate pane ID format (e.g., %1, %2, %10)
        if not opts.args:match("^%%%d+$") then
          notify_error("Invalid pane ID format. Expected: %N (e.g., %1, %2)")
          return
        end
        M.state.cached_pane_id = opts.args
        M.state.cache_time = os.time()
        notify_success("Set Claude pane to: " .. opts.args)
      end, {
        nargs = 1,
        desc = "Manually set Claude Code tmux pane ID (e.g., %2)",
      })

      vim.api.nvim_create_user_command("ClaudeClearCache", function()
        M.state.cached_pane_id = nil
        M.state.cache_time = 0
        notify_success("Cleared Claude pane cache")
      end, {
        desc = "Clear cached Claude Code pane ID",
      })
    end,
  },
}
