# command-runner.nvim

a neovim plugin that provides a UI for setting a persistent set of commands that you can then run with a keybinding or vim command without having to type them out each time

you can input the commmands in a popup window (each one on a new line) and then you can run one of them or all of them in sequence

## why use this?

the usecase i had in mind when creating this plugin was a set of build/compile commands that you would run frequently, but that you don't want to have to type out each time.
this plugin obviously makes your workflow more efficient by saving you a lot of keystrokes on subsequent runs of the commands

## installation

using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "marzeq/command-runner.nvim",
  -- these are the default options, you don't need to include them if you don't want to change them
  opts = {
    -- When running all commands, run the next command even if the previous one failed
    run_next_on_failure = false,
    -- The height of the command output split (in %)
    split_height = 25,
    -- Whether to start in insert mode in the Set buffer
    start_insert = false,
    -- Whether the cursor should be positioned at the end of the buffer in the Set buffer
    start_at_end = true,
    -- What backend to use ("native" or "redr") (default: "native")
    backend = "native",
    -- Whether to display "could not connect to redr" messages (default: true)
    redr_show_could_not_connect = true,
  },
},
```

## backends

the native backend is the default one, where everything is done in neovim (this is the one displayed in the demo)

[redr](https://github.com/marzeq/redr) is my own command runner that i wrote in go specifically for this project. it runs over tcp sockets to communicate with neovim, and has the advantage of being a separate window that you can tile however you want.
it's still pretty wip, but it's already usable. if you want to use it, (for now) please build it yourself (instructions in repo). when you want to use it, run the `redr` binary and then set the backend to "redr" in the opts

if you're worried about bloat, only the backend you're using is loaded

## demo

https://github.com/user-attachments/assets/ba7bfcb1-661b-4477-980d-4dbc12d1dfad

## usage (lua api/vim commands)

you can get access to lua api by requiring `"command-runner"` in your lua code, for example: `require("command-runner").set_commands()`


| lua function                                 | vim command                                            | shortcut in set buffer/window | description                                                           |
|----------------------------------------------|--------------------------------------------------------|-------------------------------|-----------------------------------------------------------------------|
| `set_commands()`                             | `:CommandRunnerSet`                                    |                               | opens the set buffer/window. press `<esc>` or `q` to close it         |
| `run_command(index: number)`                 | `:CommandRunnerRun {index}`                            | corresponding number `[1..9]` | runs the command at the given index                                   |
| `run_command_select_ui()`                    | `:CommandRunnerRun`                                    |                               | opens a popup window with the commands, and you can select one to run |
| `run_all_commands()`                         | `:CommandRunnerRunAll`                                 | `<CR>`                        | runs all the commands in sequence                                     |
| `run_arbitrary_command(command: string)`     | `:CommandRunnerRunArbitrary {command}`                 |                               | runs the given command                                                |
| `run_arbitrary_commands(commands: string[])` | `:CommandRunnerRunArbitrary {command1} {command2} ...` |                               | runs the given commands in sequence                                   |
| `run_arbitrary_ui()`                         | `:CommandRunnerRunArbitrary`                           |                               | opens a popup window where you can input a command to run             |

with the exception of `run_arbitrary_*` functions, all the functions will open the set buffer if no commands are set and will need to be ran again after setting the commands

## known limitations

none currently

## credits

- me

## license & usage

licensed under GPL V3 (see [LICENSE](LICENSE))

if you plan on using this plugin in a distribution, i would appreciate it if you let me know and credited me properly


