---@diagnostic disable: deprecated
local M = require("command-runner")
local uv = vim.loop

local MAX_BYTES = 16 * 1024
local REDR_PORT = 45673

---@param commands string[]
---@param cwd string
---@param run_next_after_failure boolean
local function run_message(commands, cwd, run_next_after_failure)
  return vim.json.encode({
    type = "run",
    commands = commands,
    cwd = cwd,
    run_next_after_failure = run_next_after_failure,
  }) .. "\n"
end

local function ignore_message()
  return vim.json.encode({
    type = "ignore",
  }) .. "\n"
end

---@param msg string
---@return {type: "ok"}|{type: "command_ran", exit_code: number, cmd: string, last: boolean, silent: boolean}|{type: "done"}|nil
local function parse_message(msg)
  local decoded = vim.json.decode(msg:match("([^\n]*)"))

  if decoded.type == "ok" then
    return {
      type = "ok",
    }
  elseif decoded.type == "command_ran" then
    return {
      type = "command_ran",
      exit_code = tonumber(decoded.exit_code),
      cmd = tostring(decoded.cmd),
      last = decoded.last,
      silent = decoded.silent,
    }
  else
    return nil
  end
end

---@param client unknown @The TCP client (a uv_tcp_t handle)
---@param msg string @Message to send to the server
---@param callback function @Callback to handle the response or error
local function send_message(client, msg, callback)
  client:write(msg, function(write_err)
    if write_err then
      callback(nil, write_err)
      return
    end

    local buf = ""
    local function read_cb(err, chunk)
      if err then
        callback(nil, err)
        return
      end

      if chunk then
        buf = buf .. chunk
        if buf:find("\n") then
          client:read_stop()
          callback(buf, nil)
        end
      else
        callback(nil, "Connection closed")
      end
    end

    client:read_start(read_cb)
  end)
end

---@param commands string[]
---@param cwd string
---@return "need_fallback"|nil
local function run_commands(commands, cwd)
  for _, command in ipairs(commands) do
    if #commands + 100 > MAX_BYTES then
      vim.notify("Command `" .. command .. "` exceeds 16KB limit", vim.log.levels.ERROR)
      return
    end
  end

  local function backup_run_command()
    vim.schedule(function()
      local backend = require("backends.native")
      backend.run_commands(commands, cwd)
    end)
  end

  ---@diagnostic disable-next-line: undefined-field
  local client = uv.new_tcp()
  client:connect("127.0.0.1", REDR_PORT, function(connect_err)
    if connect_err then
      if M.config.redr_show_could_not_connect then
        vim.notify("Could not connect to redr server", vim.log.levels.ERROR)
      end
      client:close()
      backup_run_command()
      return
    end

    send_message(client, run_message(commands, cwd, M.config.run_next_on_failure), function(ok_res, ok_err)
      if ok_err then
        if M.config.redr_show_could_not_connect then
          vim.notify("Error sending run message: " .. ok_err, vim.log.levels.ERROR)
        end
        client:close()
        backup_run_command()
        return
      end

      local ok_parsed = parse_message(ok_res)
      if ok_parsed == nil or ok_parsed.type ~= "ok" then
        vim.notify("Error parsing response from redr server: " .. vim.inspect(ok_res), vim.log.levels.ERROR)
        client:close()
        return
      end

      local function recursive_loop()
        send_message(client, ignore_message(), function(ignore_res, ignore_err)
          if ignore_err then
            vim.notify("Error sending ignore message: " .. ignore_err, vim.log.levels.ERROR)
            client:close()
            return
          end

          local parsed = parse_message(ignore_res)
          if not parsed then
            vim.notify("Invalid response from server: " .. vim.inspect(ignore_res), vim.log.levels.ERROR)
            client:close()
            return
          end

          if parsed.type == "command_ran" then
            if not parsed.silent then
              vim.notify(
                "Command `" .. parsed.cmd .. "` ran with exit code " .. parsed.exit_code,
                parsed.exit_code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
              )
            else
            end
            if parsed.last then
              client:close()
            else
              recursive_loop()
            end
          else
            vim.notify("Unexpected message type: " .. vim.inspect(parsed), vim.log.levels.ERROR)
            client:close()
          end
        end)
      end

      recursive_loop()
    end)
  end)
end

return {
  run_commands = run_commands,
}
