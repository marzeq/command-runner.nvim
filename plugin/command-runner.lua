vim.api.nvim_create_user_command("CommandRunnerSet", require("command-runner").set_commands, {})
vim.api.nvim_create_user_command("CommandRunnerRun", require("command-runner").run_commands, {})
