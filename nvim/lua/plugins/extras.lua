-- Imported for their non-LSP value (treesitter parsers, DAP, venv
-- selector, SchemaStore.nvim) — the actual LSP server config for every
-- server these extras touch comes from nvim/lsp/*.lua instead. See
-- lsp.lua for the mason=false overrides that keep Mason out of it.
return {
  { import = "lazyvim.plugins.extras.lang.python" },
  { import = "lazyvim.plugins.extras.lang.yaml" },
  { import = "lazyvim.plugins.extras.lang.helm" },
  { import = "lazyvim.plugins.extras.lang.docker" },
  { import = "lazyvim.plugins.extras.dap.core" },

  -- qvalentin/helm-ls.nvim (pulled in by lang.helm) is a convenience
  -- wrapper around the same helm-ls binary we already install and
  -- configure ourselves in lsp/helm_ls.lua — disabled to avoid a
  -- second, redundant path managing the same LSP.
  { "qvalentin/helm-ls.nvim", enabled = false },

  -- Per-resource Kubernetes schema selection by apiVersion/kind, so
  -- yamlls validates k8s manifests without also trying to validate
  -- unrelated yaml (e.g. Helm chart values.yaml) against that schema.
  { "imroc/kubeschema.nvim", ft = "yaml", opts = {} },
}
