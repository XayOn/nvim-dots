return {
  -- mason=false on every server we hand-configure in nvim/lsp/ tells
  -- LazyVim's core loader (lazyvim/plugins/lsp/init.lua) to call
  -- vim.lsp.config()/vim.lsp.enable() directly instead of routing the
  -- server through mason-lspconfig's automatic_enable/ensure_installed.
  -- Each server's real settings live in nvim/lsp/<name>.lua and are
  -- auto-discovered by Neovim's native lsp/ convention; the entries
  -- below exist ONLY to flip that one flag off.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        basedpyright = { mason = false },
        ruff = { mason = false },
        yamlls = { mason = false },
        helm_ls = { mason = false },
        dockerls = { mason = false },
        bashls = { mason = false },
        lua_ls = { mason = false },
      },
    },
  },

  -- Belt-and-suspenders: even with every server above opted out,
  -- mason.nvim is still an unavoidable core dependency of nvim-lspconfig
  -- in LazyVim (see lazyvim/plugins/lsp/init.lua) and gets asked by
  -- other parts of LazyVim core (e.g. nvim-treesitter, for
  -- tree-sitter-cli — installed directly in install.sh instead) to
  -- install things. A function here runs after every other opts merge,
  -- so it reliably wins regardless of what any extra tried to add to
  -- the list (plain table merges can't do this — see the LazyVim
  -- starter's own comment on vim.tbl_deep_extend not merging lists).
  {
    "mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = {}
    end,
  },
}
