local Job = require("plenary.job")

---@diagnostic disable: deprecated
---@class Config
local config = {}

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
  -- yoinked from https://github.com/dromozoa/dromozoa-shlex
  local function split(s)
    local SQ = 0x27
    local DQ = 0x22
    local SP = 0x20
    local HT = 0x09
    local LF = 0x0A
    local CR = 0x0D
    local BS = 0x5C

    local token
    local state
    local escape = false
    local result = {}
    for i = 1, #s do
      local c = s:byte(i)
      local v = string.char(c)
      if state == SQ then
        if c == SQ then
          state = nil
        else
          token[#token + 1] = v
        end
      elseif state == DQ then
        if escape then
          if c == DQ or c == BS then
            token[#token + 1] = v
          else
            token[#token + 1] = "\\"
            token[#token + 1] = v
          end
          escape = false
        else
          if c == DQ then
            state = nil
          elseif c == BS then
            escape = true
          else
            token[#token + 1] = v
          end
        end
      else
        if escape then
          token[#token + 1] = v
          escape = false
        else
          if c == SP or c == HT or c == LF or c == CR then
            if token ~= nil then
              result[#result + 1] = table.concat(token)
              token = nil
            end
          else
            if token == nil then
              token = {}
            end
            if c == SQ then
              state = SQ
            elseif c == DQ then
              state = DQ
            elseif c == BS then
              escape = true
            else
              token[#token + 1] = v
            end
          end
        end
      end
    end

    if state ~= nil then
      error("no closing quotation")
    end
    if escape then
      error("no escaped character")
    end

    if token ~= nil then
      result[#result + 1] = table.concat(token)
    end
    return result
  end

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

  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_set_current_buf(buf)

  local function write_to_buffer(b, word)
    vim.schedule(function()
      vim.api.nvim_buf_set_option(b, "modifiable", true)
      -- check if the buffer contains absolutelely nothing, to avoid adding a newline at the beginning
      if vim.api.nvim_buf_get_lines(b, 0, -1, false)[1] == "" then
        vim.api.nvim_buf_set_lines(b, 0, -1, false, { word })
      else
        vim.api.nvim_buf_set_lines(b, -1, -1, false, { word })
      end
      vim.api.nvim_buf_set_option(b, "modifiable", false)
    end)
  end

  local function handle_output(cmd, next_command)
    write_to_buffer(buf, "> " .. cmd)
    vim.notify("Running command: " .. cmd, vim.log.levels.INFO)

    local parts = split(cmd)

    local command = parts[1]
    local args = {}
    for i = 2, #parts do
      args[i - 1] = parts[i]
    end

    local job = Job:new({
      command = command,
      args = args,
      on_stdout = function(_, data)
        write_to_buffer(buf, data)
      end,
      on_stderr = function(_, data)
        write_to_buffer(buf, data)
      end,
      on_exit = function(_, code)
        write_to_buffer(buf, "Exit code: " .. code)
        write_to_buffer(buf, "")
      end,
    })

    job:start()

    if next_command ~= nil then
      job:after(function()
        handle_output(next_command)
      end)
    end
  end

  -- increment by 2 to get the next two commands
  for i = 1, #M.commands, 2 do
    local next_command = M.commands[i + 1]
    handle_output(M.commands[i], next_command)
  end
end

return M
