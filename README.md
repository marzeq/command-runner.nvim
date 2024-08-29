# command-runner.nvim

a neovim plugin that provides a UI for setting a persistent set of commands that you can then run with a keybinding or vim command without having to type them out each time

you can input the commmands in a popup window (each one on a new line) and then when you run them, the result will appear in a new buffer below the current one

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
    --Whether to start in insert mode in the Set buffer
    start_insert = false,
    --Whether the cursor should be positioned at the end of the buffer in the Set buffer
    start_at_end = true,
  },
},
```

## demo

https://github.com/user-attachments/assets/ba7bfcb1-661b-4477-980d-4dbc12d1dfad

## usage

### setting the commands

to set the commands, run `:CommandRunnerSet` and input the commands in the popup window that appears.
you can also use the lua `require("command-runner").set_commands` function to do the same thing.

when you're done, press `<esc>` or `q` to close the popup window.

if you ever want to change the commands, you can run it again, and the commands will appear there again for you to edit.

each project has it's own set of commands that are persistent accross sessions. if you are inside a git repo, the root of the repo will be stored, so no matter how deep you are in the project tree, the commands will be the same.
otherwise, the current working directory will be used as a fallback.

### running the commands

to a specific command, run `:CommandRunnerRun {index}` or use the equivalent lua function `require("command-runner").run_command(index)`.
you can also press the index of the command in the Set buffer while in normal mode to run it (obviously onlt works for indices 1-9).

to run all the commands one after the other, run `:CommandRunnerRunAll` or use the equivalent lua function `require("command-runner").run_command(nil)`.
when in the Set buffer, pressing `<CR>` in normal mode will do the same thing.

it's pretty straight forward, i think i already explained it well in the introduction.

## known limitations

none currently

## credits

- me

## license & usage

licensed under GPL V3 (see [LICENSE](LICENSE))

if you plan on using this plugin in a distribution, i would appreciate it if you let me know and credited me properly


