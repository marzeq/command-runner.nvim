---@diagnostic disable: deprecated
local M = require("command-runner")
local socket = require("socket")

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
---@return {type: "ok"}|{type: "command_ran", exit_code: number}|nil
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
  else
    return nil
  end
end

---@param client unknown @socket.unix
---@param msg string @message to send to the server
---@return string|nil, unknown|nil @response from the server
local function send_message(client, msg)
  local success, err = client:send(msg)

  if not success then
    return nil, err
  end

  ---@diagnostic disable-next-line: redefined-local
  local response, err = client:receive("*l")

  if not response then
    return nil, err
  end

  return response, nil
end

---@param commands string[]
---@param cwd string
local function run_command(commands, cwd)
  for _, command in ipairs(commands) do
    if #commands + 100 > MAX_BYTES then
      vim.notify("Command `" .. command .. "` exceeds 16KB limit", vim.log.levels.ERROR)
      return
    end
  end

  local client = socket.tcp4()
  if not client then
    vim.notify("Error connecting to redr server", vim.log.levels.ERROR)
    client:close()
    return
  end

  local success = client:connect("127.0.0.1", tostring(REDR_PORT))
  if not success then
    vim.notify("Error connecting to redr server", vim.log.levels.ERROR)
    client:close()
    return
  end

  local introduce, introduce_err = send_message(client, introduce_message(cwd))
  if introduce_err ~= nil then
    vim.notify("Error introducing to redr server: " .. vim.inspect(introduce_err), vim.log.levels.ERROR)
    client:close()
    return
  end

  ---@diagnostic disable-next-line: param-type-mismatch
  local introduce_parsed = parse_message(introduce)

  if introduce_parsed == nil or introduce_parsed.type ~= "ok" then
    vim.notify("Error parsing response from redr server: " .. vim.inspect(introduce), vim.log.levels.ERROR)
    send_message(client, bye_message())
    client:close()
    return
  end

  for _, command in ipairs(commands) do
    local msg = run_command_message(command)

    local res, err = send_message(client, msg)

    if err ~= nil then
      vim.notify("Error receiving response from redr server: " .. vim.inspect(err), vim.log.levels.ERROR)
      send_message(client, bye_message())
      client:close()
      return
    end

    ---@diagnostic disable-next-line: param-type-mismatch
    local parsed = parse_message(res)

    if parsed == nil or parsed.type ~= "command_ran" then
      vim.notify("Error parsing response from redr server: " .. vim.inspect(res), vim.log.levels.ERROR)
      send_message(client, bye_message())
      client:close()
      return
    end

    local exit_code = parsed.exit_code

    if exit_code == 0 then
      vim.notify("Command `" .. command .. "` ran successfully", vim.log.levels.INFO)
    else
      vim.notify("Command `" .. command .. "` failed with exit code " .. exit_code, vim.log.levels.ERROR)
      if not M.config.run_next_on_failure then
        send_message(client, bye_message())
        client:close()
        return
      end
    end
  end

  send_message(client, bye_message())
  client:close()
end

return {
  run_command = run_command,
}
