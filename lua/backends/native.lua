---@diagnostic disable: deprecated
local M = require("command-runner")

local function find_locations(str, pattern)
  local results = {}
  local start_pos = 1

  while true do
    local s, e, _ = string.find(str, pattern, start_pos)
    if not s then
      break
    end
    table.insert(results, { start_index = s, end_index = e })
    start_pos = e + 1
  end

  return results
end

local function smart_goto_file()
  local line = vim.fn.getline(".")
  local col = vim.fn.col(".")

  local pattern_full = "([^:%s]+):(%d+):(%d+)"
  local pattern_partial = "([^:%s]+):(%d+)"

  local open_file = function(filename, linenum, columnnum)
    vim.cmd(string.format("edit +%d %s", linenum, filename))
    if columnnum then
      if columnnum > vim.fn.strdisplaywidth(vim.fn.getline(linenum)) then
        columnnum = vim.fn.strdisplaywidth(vim.fn.getline(linenum))
      elseif columnnum < 1 then
        columnnum = 1
      end
      vim.cmd(string.format("normal! %d|", columnnum))
    end
  end

  local finds = find_locations(line, pattern_full)
  for _, find_info in ipairs(finds) do
    if col >= find_info.start_index and col <= find_info.end_index then
      local match = string.sub(line, find_info.start_index, find_info.end_index)
      local filename, l, c = string.match(match, pattern_full)
      open_file(filename, tonumber(l), tonumber(c))
      return
    end
  end

  finds = find_locations(line, pattern_partial)
  for _, find_info in ipairs(finds) do
    if col >= find_info.start_index and col <= find_info.end_index then
      local match = string.sub(line, find_info.start_index, find_info.end_index)
      local filename, l = string.match(match, pattern_partial)
      open_file(filename, tonumber(l))
      return
    end
  end

  local cfile = vim.fn.expand("<cfile>")
  if cfile ~= "" then
    vim.cmd("edit " .. cfile)
  end
end

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

  vim.keymap.set("n", "gf", smart_goto_file, { buffer = buf, noremap = true, silent = true })

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
