local _MODREV, _SPECREV = "scm", "-1"
rockspec_format = "3.0"
package = "command-runner.nvim"
version = _MODREV .. _SPECREV

description = {
  summary = "a simple command runner for neovim",
  labels = { "neovim" },
  homepage = "http://github.com/marzeq/command-runner.nvim",
  license = "GPL-3.0",
}

dependencies = {
  "lua >= 5.1, < 5.4",
  "luasocket",
}

source = {
  url = "git://github.com/marzeq/command-runner.nvim",
}

build = {
  type = "builtin",
}
