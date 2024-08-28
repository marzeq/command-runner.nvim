# command-runner.nvim

a neovim plugin that provides a UI for setting a persistent set of commands that you can then run with a keybinding or vim command without having to type them out each time

you can input the commmands in a popup window (each one on a new line) and then when you run them, the result will appear in a new buffer below the current one

## why use this?

the usecase i had in mind when creating this plugin was a set of build/compile commands that you would run frequently, but that you don't want to have to type out each time.
this plugin obviouslt makes your workflow more efficient by saving you a lot of keystrokes on subsequent runs of the commands

## installation

using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "marzeq/command-runner.nvim",
  opts = {}, -- no configuration yet, but this is for when there is one
},
```

## usage

### setting the commands

to set the commands, run `:CommandRunnerSet` and input the commands in the popup window that appears.
you can also use the lua `require("command-runner.nvim").set_commands` function to do the same thing.

when you're done, press `<esc>` or `q` to close the popup window.

if you ever want to change the commands, you can run it again, and the commands will appear there again for you to edit.

### running the commands

to run the commands, run `:CommandRunnerRun` or use the equivalent lua function `require("command-runner.nvim").run_commands`.

it's pretty straight forward, i think i already explained it well in the introduction.

## credits

- me

## license & usage

licensed under MIT (see [LICENSE](LICENSE))

if you plan on using this plugin in a distribution, i would appreciate it if you let me know and credited me properly


