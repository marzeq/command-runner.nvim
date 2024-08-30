---@diagnostic disable: deprecated
---@class Config
local config = {
  ---@type boolean @Run the next command even if the previous one failed (default: false)
  run_next_on_failure = false,
  ---@type number @The height of the command output split (in %) (default: 25)
  split_height = 25,
  ---@type boolean @Whether to start in insert mode in the Set buffer (default: false)
  start_insert = false,
  ---@type boolean @Whether the cursor should be positioned at the end of the buffer in the Set buffer (default: true)
  start_at_end = true,
}

local function load_json(filepath)
  local file = io.open(filepath, "r")

  if file then
    local data = file:read("*a")
    file:close()
    return vim.fn.json_decode(data)
  else
    vim.fn.writefile({ vim.fn.json_encode({}) }, filepath)
    return {}
  end
end

local config_fp = vim.fn.stdpath("data") .. "/command-runner-persistent-data.json"

---@class MyModule
local M = {
  ---@type Config
  config = config,
}

---@param args Config?
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

local function add_entry(path, commands)
  local loaded = load_json(config_fp)
  loaded[path] = commands
  vim.fn.writefile({ vim.fn.json_encode(loaded) }, config_fp)
end

local function get_dir_absolute()
  local git_dir = vim.fn.systemlist("git rev-parse --show-toplevel 2> /dev/null")[1]
  if git_dir ~= nil and git_dir ~= "" then
    return git_dir .. "/"
  end

  local cwd = vim.fn.getcwd()
  return vim.fn.fnamemodify(cwd, ":p")
end

M.set_commands_directly = function(commands)
  add_entry(get_dir_absolute(), commands)
end

M.get_commands = function()
  local loaded = load_json(config_fp)
  return loaded[get_dir_absolute()] or {}
end

M.set_commands = function()
  local cmds = M.get_commands()
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
    title = "Commands (each on new line)",
    title_pos = "center",
    border = "rounded",
  }

  vim.api.nvim_open_win(buf, true, opts)

  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "relativenumber", false)
  vim.api.nvim_buf_set_option(buf, "number", true)

  vim.api.nvim_buf_set_keymap(buf, "n", "<ESC>", "<cmd>close<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })

  vim.api.nvim_buf_set_keymap(
    buf,
    "n",
    "<CR>",
    "<cmd>close<CR><cmd>lua require('command-runner').run_command(nil)<CR>",
    { noremap = true, silent = true }
  )
  for i = 1, #cmds do
    vim.api.nvim_buf_set_keymap(
      buf,
      "n",
      tostring(i),
      "<cmd>close<CR><cmd>lua require('command-runner').run_command(" .. i .. ")<CR>",
      { noremap = true, silent = true }
    )
  end

  vim.api.nvim_create_autocmd({ "BufLeave" }, {
    buffer = buf,
    callback = function()
      if vim.api.nvim_buf_is_valid(buf) then
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

        local commands = vim.tbl_map(function(line)
          return vim.trim(line)
        end, lines)
        commands = vim.tbl_filter(function(line)
          return line ~= ""
        end, commands)

        M.set_commands_directly(commands)
      end
    end,
  })

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, cmds)

  if M.config.start_at_end and #cmds > 0 then
    vim.api.nvim_win_set_cursor(0, { #cmds, #cmds[#cmds] })
  end

  if M.config.start_insert then
    vim.api.nvim_feedkeys("a", "n", true)
  end
end

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
    vim.notify(
      "Opening " .. filename .. " at line " .. linenum .. (columnnum and " and column " .. columnnum or ""),
      vim.log.levels.INFO
    )
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

---@param index number|string|nil @The index of the command to run, nil for running all
M.run_command = function(index)
  local commands = M.get_commands()

  if #commands == 0 then
    vim.notify("No commands to run, opening setter window to set commands", vim.log.levels.ERROR)
    M.set_commands()
    return
  end

  if index ~= nil then
    index = tonumber(index)

    if index < 1 or index > #commands then
      vim.notify("Invalid index", vim.log.levels.ERROR)
      return
    end
  end

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

  if index ~= nil then
    commands = { commands[index] }
  end

  vim.fn.termopen({ shell, "-c", concat_commands(commands) })

  vim.api.nvim_feedkeys("i", "n", true)

  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
end

return M
