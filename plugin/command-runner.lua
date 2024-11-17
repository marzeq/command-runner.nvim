vim.api.nvim_create_user_command("CommandRunnerSet", require("command-runner").set_commands, {})

vim.api.nvim_create_user_command("CommandRunnerRunAll", function()
  require("command-runner").run_all_commands()
end, {})
vim.api.nvim_create_user_command("CommandRunnerRun", function(args)
  local cr = require("command-runner")

  if #args.fargs == 0 then
    cr.run_command_select_ui()
    return
  end

  local index = tonumber(args.fargs[1])
  if index == nil then
    vim.notify("Invalid index", vim.log.levels.ERROR)
    return
  else
    cr.run_command(index)
  end
end, {
  nargs = "?",
})

vim.api.nvim_create_user_command("CommandRunnerRunArbitrary", function(args)
  local cr = require("command-runner")

  local command = args.fargs

  if #command == 0 then
    cr.run_arbitrary_ui()
  elseif #command == 1 then
    cr.run_arbitrary_command(command[1])
  else
    cr.run_arbitrary_commands(command)
  end
end, {
  nargs = "*",
})
