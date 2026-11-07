-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.lazyvim_python_lsp = "basedpyright"
vim.g.lazyvim_php_lsp = "intelephense"

-- Inside a devcontainer there is no Wayland socket: copy through the terminal (Ghostty) via OSC 52.
if not vim.env.WAYLAND_DISPLAY and not vim.env.DISPLAY then
  vim.g.clipboard = "osc52"
end
