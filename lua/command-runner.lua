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
  ---@type "native"|"redr" @What backend to use ("native" or "redr") (default: "native")
  backend = "native",
  ---@type boolean @Whether to display "could not connect to redr" messages (default: true)
  redr_show_could_not_connect = true,
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
    "<cmd>close<CR><cmd>lua require('command-runner').run_all_commands()<CR>",
    { noremap = true, silent = true }
  )
  for i = 1, 9 do
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

M.check_set_commands = function()
  local commands = M.get_commands()

  if #commands == 0 then
    vim.notify("No commands to run, opening setter window to set commands", vim.log.levels.ERROR)
    M.set_commands()
    return false
  end

  return true
end

---@param commands string[] @The commands to run
M.run_arbitrary_commands = function(commands)
  if M.config.backend == "native" then
    local backend = require("backends.native")
    backend.run_commands(commands, get_dir_absolute())
  elseif M.config.backend == "redr" then
    local backend = require("backends.redr")
    backend.run_commands(commands, get_dir_absolute())
  else
    vim.notify("Invalid backend", vim.log.levels.ERROR)
  end
end

---@param command string @The command to run
M.run_arbitrary_command = function(command)
  M.run_arbitrary_commands({ command })
end

M.run_arbitrary_ui = function()
  vim.ui.input({
    prompt = "Enter command: ",
    default = "",
  }, function(input)
    if input == nil or input == "" then
      vim.notify("No command entered", vim.log.levels.ERROR)
      return
    end

    M.run_arbitrary_command(input)
  end)
end

---@param index number @The index of the command to run, nil for running all
M.run_command = function(index)
  local commands = M.get_commands()

  if not M.check_set_commands() then
    return
  end

  if index < 1 or index > #commands then
    vim.notify("Invalid index, must be in range [1.." .. #commands .. "]", vim.log.levels.ERROR)
    return
  end

  M.run_arbitrary_commands({ commands[index] })
end

M.run_command_select_ui = function()
  local commands = M.get_commands()

  if not M.check_set_commands() then
    return
  end

  local indexes = {}

  for i, _ in ipairs(commands) do
    table.insert(indexes, tostring(i))
  end

  vim.ui.select(indexes, {
    prompt = "Select command to run: ",
    format_item = function(item)
      return item .. ": " .. commands[tonumber(item)]
    end,
  }, function(choice)
    if choice == nil then
      return
    end

    ---@diagnostic disable-next-line: param-type-mismatch
    M.run_command(tonumber(choice))
  end)
end

M.run_all_commands = function()
  local commands = M.get_commands()

  if not M.check_set_commands() then
    return
  end

  M.run_arbitrary_commands(commands)
end

return M
