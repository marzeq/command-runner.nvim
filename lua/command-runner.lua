local Job = require("plenary.job")

---@diagnostic disable: deprecated
---@class Config
local config = {
  ---@type boolean
  run_next_on_failure = false,
}

---@class MyModule
local M = {
  ---@type Config
  config = config,

  ---@type string[]
  commands = {},
}

---@param args Config?
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

M.set_commands = function()
  local buf = vim.api.nvim_create_buf(false, true)

  local width = 50
  local height = 10
  local opts = {
    style = "minimal",
    relative = "editor",
    width = width,
    height = height,
    row = (vim.o.lines - height) / 2,
    col = (vim.o.columns - width) / 2,
    border = "single",
  }

  vim.api.nvim_open_win(buf, true, opts)

  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)

  vim.api.nvim_buf_set_keymap(buf, "n", "<ESC>", "<cmd>close<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })

  vim.api.nvim_create_autocmd({ "BufLeave" }, {
    buffer = buf,
    callback = function()
      if vim.api.nvim_buf_is_valid(buf) then
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

        M.commands = vim.tbl_map(function(line)
          return vim.trim(line)
        end, lines)
        -- filter out linex that are empty
        M.commands = vim.tbl_filter(function(line)
          return line ~= ""
        end, M.commands)
      end
    end,
  })

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.commands)
end

M.run_commands = function()
  if #M.commands == 0 then
    vim.notify("No commands to run", vim.log.levels.ERROR)
    return
  end

  local height = math.ceil(vim.o.lines * 0.25)
  local original_splitbelow = vim.api.nvim_get_option("splitbelow")
  vim.api.nvim_set_option("splitbelow", true)
  vim.cmd("split")
  vim.api.nvim_set_option("splitbelow", original_splitbelow)
  vim.cmd("resize " .. height)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)

  vim.api.nvim_buf_set_keymap(buf, "n", "<ESC>", "<cmd>close<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })

  local joiner = M.config.run_next_on_failure and "; " or " && "
  local shell = vim.o.shell

  local function concat_commands()
    local commands = vim.tbl_map(function(command)
      return "echo 'Running command: " .. command .. "' && " .. command .. " && echo '\n'"
    end, M.commands)

    return table.concat(commands, joiner)
  end

  vim.fn.termopen({ shell, "-c", concat_commands() }, {
    on_stdout = function()
      vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buf), 0 })
    end,
    on_stderr = function()
      vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buf), 0 })
    end,
  })

  vim.cmd("resize " .. height)

  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
end

return M
