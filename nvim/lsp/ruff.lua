vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == "ruff" then
      -- basedpyright provides hover; ruff's is redundant/less useful.
      client.server_capabilities.hoverProvider = false
    end
  end,
})

return {
  cmd = { "ruff", "server" },
  filetypes = { "python" },
  root_markers = { "pyproject.toml", "setup.cfg", ".git" },
}
