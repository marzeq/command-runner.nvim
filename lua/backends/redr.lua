---@diagnostic disable: deprecated
local M = require("command-runner")
local uv = vim.loop

local MAX_BYTES = 16 * 1024
local REDR_PORT = 45673

---@param cwd string
local function introduce_message(cwd)
  return vim.json.encode({
    type = "introduce",
    cwd = cwd,
  }) .. "\n"
end

local function run_command_message(command)
  return vim.json.encode({
    type = "run_command",
    command = command,
  }) .. "\n"
end

local function bye_message()
  return vim.json.encode({
    type = "bye",
  }) .. "\n"
end

---@param msg string
---@return {type: "ok"}|{type: "command_ran", exit_code: number}|{type: "kick_off"}|nil
local function parse_message(msg)
  local decoded = vim.json.decode(msg)

  if decoded.type == "ok" then
    return {
      type = "ok",
    }
  elseif decoded.type == "command_ran" then
    return {
      type = "command_ran",
      exit_code = tonumber(decoded.exit_code),
    }
  elseif decoded.type == "kick_off" then
    return {
      type = "kick_off",
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
    local read_cb

    read_cb = function(err, chunk)
      if err then
        callback(nil, err)
        return
      end

      if chunk then
        buf = buf .. chunk
        -- Since we're expecting a newline-terminated message
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
local function run_command(commands, cwd)
  for _, command in ipairs(commands) do
    if #commands + 100 > MAX_BYTES then
      vim.notify("Command `" .. command .. "` exceeds 16KB limit", vim.log.levels.ERROR)
      return
    end
  end

  local function backup_run_command(commands, cwd)
    vim.schedule(function()
      local backend = require("backends.native")
      backend.run_command(commands, cwd)
    end)
  end

  ---@diagnostic disable-next-line: undefined-field
  local client = uv.new_tcp()
  client:connect("127.0.0.1", REDR_PORT, function(connect_err)
    if connect_err then
      vim.notify("Error connecting to redr server: " .. connect_err, vim.log.levels.ERROR)
      client:close()
      backup_run_command(commands, cwd)
      return
    end

    send_message(client, introduce_message(cwd), function(introduce_res, introduce_err)
      if introduce_err then
        vim.notify("Error connecting to redr server: " .. introduce_err, vim.log.levels.ERROR)
        client:close()
        backup_run_command(commands, cwd)
        return
      end

      local introduce_parsed = parse_message(introduce_res)
      if introduce_parsed == nil or introduce_parsed.type ~= "ok" then
        if introduce_parsed ~= nil and introduce_parsed.type == "kick_off" then
          return
        end
        vim.notify("Error parsing response from redr server: " .. vim.inspect(introduce_res), vim.log.levels.ERROR)
        send_message(client, bye_message(), function()
          client:close()
        end)
        return
      end

      local function process_command(index)
        if index > #commands then
          send_message(client, bye_message(), function()
            client:close()
          end)
          return
        end

        local command = commands[index]
        local msg = run_command_message(command)

        send_message(client, msg, function(res, err)
          if err then
            vim.notify("Error receiving response from redr server: " .. err, vim.log.levels.ERROR)
            send_message(client, bye_message(), function()
              client:close()
            end)
            return
          end

          local parsed = parse_message(res)
          if parsed == nil or parsed.type ~= "command_ran" then
            if parsed ~= nil and parsed.type == "kick_off" then
              return
            end
            vim.notify("Error parsing response from redr server: " .. vim.inspect(res), vim.log.levels.ERROR)
            send_message(client, bye_message(), function()
              client:close()
            end)
            return
          end

          local exit_code = parsed.exit_code
          if exit_code == 0 then
            vim.notify("Command `" .. command .. "` ran successfully", vim.log.levels.INFO)
          else
            vim.notify("Command `" .. command .. "` failed with exit code " .. exit_code, vim.log.levels.ERROR)
            if not M.config.run_next_on_failure then
              send_message(client, bye_message(), function()
                client:close()
              end)
              return
            end
          end

          process_command(index + 1)
        end)
      end

      process_command(1)
    end)
  end)
end

return {
  run_command = run_command,
}
