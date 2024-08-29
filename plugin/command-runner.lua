vim.api.nvim_create_user_command("CommandRunnerSet", require("command-runner").set_commands, {})
vim.api.nvim_create_user_command("CommandRunnerRunAll", function()
  require("command-runner").run_command(nil)
end, {})
vim.api.nvim_create_user_command("CommandRunnerRun", function(args)
  require("command-runner").run_command(tonumber(args.fargs[1]))
end, {
  nargs = 1,
})
