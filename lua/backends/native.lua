---@diagnostic disable: deprecated
local M = require("command-runner")

---@param commands string[]
---@param cwd string cwd
local function run_commands(commands, cwd)
  local height = math.ceil(vim.o.lines * (M.config.split_height / 100))

  local win = vim.api.nvim_open_win(vim.api.nvim_create_buf(true, true), true, {
    vertical = true,
    split = "below",
    style = "minimal",
    width = vim.o.columns,
    height = height,
  })

  local buf = vim.api.nvim_win_get_buf(win)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].filetype = "commandrunner"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].bufhidden = "wipe"

  local function close()
    vim.api.nvim_win_close(win, true)
  end

  local function open(mode)
    return "<C-w>" .. mode .. "<C-w>k<cmd>close<CR><C-w>j<cmd>resize " .. height .. "<CR><C-w>k"
  end

  vim.keymap.set("n", "<ESC>", close, { noremap = true, silent = true, buffer = buf })
  vim.keymap.set("n", "<CR>", close, { noremap = true, silent = true, buffer = buf })
  vim.keymap.set("n", "q", close, { noremap = true, silent = true, buffer = buf })
  vim.keymap.set("n", "gf", open("f"), { noremap = true, silent = true, buffer = buf })
  vim.keymap.set("n", "gF", open("F"), { noremap = true, silent = true, buffer = buf })

  local joiner = M.config.run_next_on_failure and "; " or " && "
  local shell = vim.o.shell

  local function concat_commands(cmds)
    local mapped = vim.tbl_map(function(command)
      return "echo '> " .. command .. "' && " .. command .. " && echo ''"
    end, cmds)
    return table.concat(mapped, joiner)
  end

  vim.fn.termopen({ shell, "-c", concat_commands(commands) }, {
    on_exit = function()
      vim.api.nvim_command("stopinsert")
    end,
  })
end

return {
  run_commands = run_commands,
}
