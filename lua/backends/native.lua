---@diagnostic disable: deprecated
local M = require("command-runner")

---@param commands string[]
---@param _ string cwd
local function run_commands(commands, _)
  local height = math.ceil(vim.o.lines * (M.config.split_height / 100))
  local original_splitbelow = vim.api.nvim_get_option("splitbelow")
  vim.api.nvim_set_option("splitbelow", true)
  vim.cmd("split")
  vim.api.nvim_set_option("splitbelow", original_splitbelow)
  vim.cmd("resize " .. height)

  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_set_current_buf(buf)

  vim.api.nvim_buf_set_keymap(buf, "n", "<ESC>", "<cmd>close<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })

  local joiner = M.config.run_next_on_failure and "; " or " && "
  local shell = vim.o.shell

  local function concat_commands(cmds)
    local mapped = vim.tbl_map(function(command)
      return "echo '> " .. command .. "' && " .. command .. " && echo ''"
    end, cmds)

    return table.concat(mapped, joiner)
  end

  vim.fn.termopen({ shell, "-c", concat_commands(commands) })

  vim.api.nvim_feedkeys("i", "n", true)

  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
end

return {
  run_commands = run_commands,
}
