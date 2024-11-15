---@diagnostic disable: deprecated
local M = require("command-runner")
local uv = vim.loop

local MAX_BYTES = 16 * 1024
local REDR_PORT = 45673

---@param cwd string
---@param run_next_after_failure boolean
local function introduce_message(cwd, run_next_after_failure)
  return vim.json.encode({
    type = "introduce",
    cwd = cwd,
    run_next_after_failure = run_next_after_failure,
  }) .. "\n"
end

local function run_commands_message(commands)
  return vim.json.encode({
    type = "run_commands",
    commands = commands,
  }) .. "\n"
end

local function bye_message()
  return vim.json.encode({
    type = "bye",
  }) .. "\n"
end

local function ok_message()
  return vim.json.encode({
    type = "ok",
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
      if M.config.redr_show_could_not_connect then
        vim.notify("Could not connect to redr server", vim.log.levels.ERROR)
      end
      client:close()
      backup_run_command(commands, cwd)
      return
    end

    send_message(client, introduce_message(cwd, M.config.run_next_on_failure), function(introduce_res, introduce_err)
      if introduce_err then
        if M.config.redr_show_could_not_connect then
          vim.notify("Error sending introduce message: " .. introduce_err, vim.log.levels.ERROR)
        end
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

      send_message(client, run_commands_message(commands), function(run_commands_res, run_commands_err)
        if run_commands_err then
          vim.notify("Error sending run_commands message: " .. run_commands_err, vim.log.levels.ERROR)
          client:close()
          backup_run_command(commands, cwd)
          return
        end

        local command_parsed = parse_message(run_commands_res)
        if command_parsed == nil or command_parsed.type ~= "command_ran" then
          vim.notify("Error parsing response from redr server: " .. vim.inspect(run_commands_res), vim.log.levels.ERROR)
          send_message(client, bye_message(), function()
            client:close()
          end)
          return
        end

        if command_parsed.exit_code ~= 0 then
          vim.notify(
            "Command `" .. commands[1] .. "` failed with exit code " .. command_parsed.exit_code,
            vim.log.levels.ERROR
          )
          send_message(client, bye_message(), function()
            client:close()
          end)
          return
        end

        vim.notify("Command `" .. commands[1] .. "` ran successfully", vim.log.levels.INFO)

        local function process_command_result(i)
          send_message(client, ok_message(), function(command_res, command_err)
            if command_err then
              vim.notify("Error acknowledging command result: " .. command_err, vim.log.levels.ERROR)
              client:close()
              return
            end

            ---@diagnostic disable-next-line: redefined-local
            local command_parsed = parse_message(command_res)
            if command_parsed == nil then
              vim.notify("Unexpected response from server: " .. vim.inspect(command_res), vim.log.levels.ERROR)
              return
            end

            if command_parsed.type == "command_ran" then
              local command = commands[i]
              if command_parsed.exit_code ~= 0 then
                vim.notify(
                  "Command `" .. command .. "` failed with exit code " .. command_parsed.exit_code,
                  vim.log.levels.ERROR
                )
                send_message(client, bye_message(), function()
                  client:close()
                end)
                return
              end
              vim.notify("Command `" .. command .. "` ran successfully", vim.log.levels.INFO)
              process_command_result(i + 1)
            elseif command_parsed.type == "ok" then
              send_message(client, bye_message(), function()
                client:close()
              end)
            end
          end)
        end

        process_command_result(2)
      end)
    end)
  end)
end

return {
  run_command = run_command,
}
