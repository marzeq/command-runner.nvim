---@diagnostic disable: deprecated
---@class Config
local config = {
  ---@type boolean @Run the next command even if the previous one failed (default: false)
  run_next_on_failure = false,
  ---@type number @The height of the command output split (in %) (default: 25)
  split_height = 25,
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

local function get_cwd_absolute()
  local cwd = vim.fn.getcwd()
  return vim.fn.fnamemodify(cwd, ":p")
end

local function set_commands(commands)
  add_entry(get_cwd_absolute(), commands)
end

local function get_commands()
  local loaded = load_json(config_fp)
  return loaded[get_cwd_absolute()] or {}
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

        local commands = vim.tbl_map(function(line)
          return vim.trim(line)
        end, lines)
        commands = vim.tbl_filter(function(line)
          return line ~= ""
        end, commands)

        set_commands(commands)
      end
    end,
  })

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, get_commands())
end

M.run_commands = function()
  local commands = get_commands()

  if #commands == 0 then
    vim.notify("No commands to run", vim.log.levels.ERROR)
    return
  end

  local height = math.ceil(vim.o.lines * (M.config.split_height / 100))
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

  local function concat_commands(cmds)
    local mapped = vim.tbl_map(function(command)
      return "echo '> " .. command .. "' && " .. command .. " && echo ''"
    end, cmds)

    return table.concat(mapped, joiner)
  end

  vim.fn.termopen({ shell, "-c", concat_commands(commands) })

  vim.api.nvim_feedkeys("i", "n", true)

  vim.cmd("resize " .. height)

  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
end

return M
