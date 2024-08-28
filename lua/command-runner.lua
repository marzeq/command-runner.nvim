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
  if #M.commands == 0 then
    vim.notify("No commands to run", vim.log.levels.ERROR)
    return
  end

  vim.notify("Running commands", vim.log.levels.INFO)

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
    vim.api.nvim_buf_set_option(b, "modifiable", true)
    -- check if the buffer contains absolutelely nothing, to avoid adding a newline at the beginning
    if vim.api.nvim_buf_get_lines(b, 0, -1, false)[1] == "" then
      vim.api.nvim_buf_set_lines(b, 0, -1, false, { word })
    else
      vim.api.nvim_buf_set_lines(b, -1, -1, false, { word })
    end
    vim.api.nvim_buf_set_option(b, "modifiable", false)
  end

  local function handle_output(cmd)
    write_to_buffer(buf, "> " .. cmd)
    local handle = io.popen(cmd .. " 2>&1")
    if handle == nil then
      write_to_buffer(buf, "Error running command: " .. cmd)
      write_to_buffer(buf, "")
      return
    end
    for line in handle:lines() do
      write_to_buffer(buf, line)
    end
    handle:close()
    write_to_buffer(buf, "")
  end

  for _, cmd in ipairs(M.commands) do
    handle_output(cmd)
  end
end

return M
