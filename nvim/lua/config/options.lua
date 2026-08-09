-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Must be set before lazyvim.plugins.extras.lang.python loads, since it
-- reads this global as its default at require-time.
vim.g.lazyvim_python_lsp = "basedpyright"
