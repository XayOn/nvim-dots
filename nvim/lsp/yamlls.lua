-- Base config, auto-discovered by vim.lsp.enable("yamlls"). The
-- imported LazyVim lang.yaml extra (see lua/plugins/extras.lua) layers
-- a before_init hook on top of this that pulls live schemas from
-- b0o/SchemaStore.nvim — that's why schemaStore.enable is false here:
-- built-in schema fetching is disabled in favor of the plugin's copy.
return {
  cmd = { "yaml-language-server", "--stdio" },
  filetypes = { "yaml", "yaml.docker-compose", "yaml.gitlab" },
  root_markers = { ".git" },
  -- kubeschema.nvim (lua/plugins/extras.lua) needs dynamic registration
  -- enabled and its on_attach hook to assign a schema per-buffer from
  -- apiVersion/kind, instead of a single static schema for every yaml
  -- file (which is what let a chart's values.yaml get validated against
  -- the Kubernetes schema before).
  capabilities = {
    workspace = {
      didChangeConfiguration = {
        dynamicRegistration = true,
      },
    },
  },
  on_attach = function(...)
    require("kubeschema").on_attach(...)
  end,
  settings = {
    yaml = {
      keyOrdering = false,
      -- No forced kubernetes = "*.yaml" mapping — kubeschema.nvim
      -- picks a schema per-buffer from apiVersion/kind instead, so a
      -- chart's values.yaml (which is not a Kubernetes resource) isn't
      -- wrongly validated against the Kubernetes schema.
      schemaStore = {
        enable = false,
        url = "",
      },
    },
  },
}
