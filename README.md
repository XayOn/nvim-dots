# nvim-dots

Neovim, configured to live *inside* devcontainers rather than being
bind-mounted from the host — because the host here is sometimes NixOS
(binaries linked against `/nix/store`, which doesn't exist in Debian-
based devcontainer images) and the container runner is
[crib](https://github.com/fgrehm/crib), not the official devcontainer
CLI.

- Neovim 0.12.x, LazyVim base + `lang.python`/`lang.yaml`/`lang.helm`/
  `lang.docker`/`dap.core` extras, native `vim.lsp.config()`/
  `vim.lsp.enable()` LSP configs per server under `nvim/lsp/` (no
  `require('lspconfig').X.setup{}`).
- **No Mason.** LSPs install via `uv tool install` (Python), a
  bootstrapped Node.js + `npm -g` (the three LSPs with no standalone
  binary), or direct checksummed release binaries (everything else,
  including the Neovim binary itself and `tree-sitter-cli`). See
  `NOTES.md` for exactly why Mason can't be fully removed from
  LazyVim's plugin graph and how `mason = false` + a function-based
  `opts` override neutralize it anyway.
- `lazy.nvim` for plugin management (not `vim.pack`), with
  `lazy-lock.json` committed and restored via `Lazy! restore` — exact
  pins, not "whatever's latest."
- Two [crib](https://github.com/fgrehm/crib) profiles (personal/work),
  each with its own persistent `/nvim/{share,state,cache}` volumes and
  git identity, switched via shell functions that scope
  `XDG_CONFIG_HOME` to a single command.

## Install (inside a devcontainer, via crib's dotfiles plugin)

Point `[dotfiles].repository` at this repo in
`~/.profiles/{personal,work}/crib/config.toml` (see below) — crib
clones it and auto-runs `install.sh` on `crib up`. No manual step
needed for normal use.

To run it by hand (e.g. for testing):

```sh
sh install.sh   # not ./install.sh — see NOTES.md for why sh matters
```

Idempotent — safe to re-run. Installs to `/opt`, `/usr/local/bin`, and
`/nvim/{share,state,cache}` (created + chowned every run, since a
freshly mounted volume often starts out root-owned).

## crib profiles

```
~/.profiles/personal/crib/config.toml
~/.profiles/work/crib/config.toml
```

Both set `[dotfiles].repository` to this repo, `[workspace].env` with
`DEV_PROFILE`/`GIT_AUTHOR_NAME`/`GIT_AUTHOR_EMAIL`/
`GIT_COMMITTER_NAME`/`GIT_COMMITTER_EMAIL`/`EDITOR`/`SSH_AUTH_SOCK`,
and `[workspace].mount` for three per-profile named volumes
(`crib-nvim-{share,state,cache}-<profile>` → `/nvim/*`) plus the host's
SSH agent socket bound to `/ssh-agent`.

`shell/crib-profiles.sh` (source it from `.zshrc`/`.bashrc`) defines:

```sh
crib       # personal profile — XDG_CONFIG_HOME=~/.profiles/personal for this command only
crib-work  # work profile     — XDG_CONFIG_HOME=~/.profiles/work for this command only
```

The `XDG_CONFIG_HOME` override is a shell prefix-assignment on a
single `command crib` call — it never leaks into the rest of the
shell's environment.

`lua/config/profile.lua` reads `DEV_PROFILE` at runtime and exposes
`{name, is_work}`, so any plugin spec can gate itself on the profile
(e.g. skip anything that phones home when `is_work`).

## Repo layout

```
install.sh                    # idempotent installer, see NOTES.md for the sh/bash gotcha
bin/nvim-wrapper              # installed as /usr/local/bin/nvim, sets XDG_*_HOME=/nvim/*
shell/crib-profiles.sh        # crib / crib-work shell functions
verify.sh                     # scripted acceptance checks for phases 1, 3, 4
NOTES.md                      # everything crib's docs didn't cover, found empirically
nvim/
  init.lua                    # -> require("config.lazy")
  lazy-lock.json              # committed — exact plugin pins, restored via `Lazy! restore`
  lua/config/
    lazy.lua                  # lazy.nvim bootstrap + LazyVim import
    options.lua               # vim.g.lazyvim_python_lsp = "basedpyright"
    keymaps.lua
    profile.lua               # DEV_PROFILE -> {name, is_work}
  lua/plugins/
    extras.lua                # LazyVim extras import + qvalentin/helm-ls.nvim disabled + kubeschema.nvim
    lsp.lua                   # mason=false per server + mason.nvim ensure_installed={} override
  lsp/                        # native per-server configs, auto-discovered by vim.lsp.enable()
    basedpyright.lua
    ruff.lua                  # disables its own hoverProvider so basedpyright's wins
    yamlls.lua                # kubeschema.nvim wiring, schemaStore.enable=false
    helm_ls.lua
    dockerls.lua
    bashls.lua
    lua_ls.lua
```

## Verifying

```sh
./verify.sh
```

Runs the phase 1 (install.sh + checkhealth, invoked exactly as crib
would — `sh install.sh`), phase 3 (crib profiles → distinct volumes +
correct git identity), and phase 4 (remoteUser=root and remoteUser=
vscode both work unchanged) acceptance checks against real Docker
containers. Phase 2's acceptance ("open a .py with a venv and see
diagnostics from both LSPs; open a Deployment and get field
completion; open a chart's values.yaml and *don't* get validated
against the Kubernetes schema") isn't scripted — it's an interactive/
visual check — but was verified the same way during development; see
the phase 2 commit message for exactly what was checked and how.

## What's still a placeholder

`[dotfiles].repository` in both profile configs points at
`git@github.com:xayon/nvim-dots.git`, which doesn't exist yet. Push
this repo there (or wherever) and update both `config.toml` files.
crib's dotfiles plugin fails open on a clone error (logs a warning,
doesn't block `crib up` — see `NOTES.md`), so nothing else here is
blocked by this being unset correctly.

## Anti-goals (deliberately not done)

- No project `devcontainer.json` files were modified — everything
  here is injected by crib's plugins (`mount`/`env`) or crib's
  dotfiles clone, never the project's own devcontainer config.
- No cluster-management plugins (`kubectl.nvim`, a `k9s` integration,
  etc.) — those belong in the host's own Neovim, not inside a
  container that shouldn't have cluster credentials.
- `Lazy! sync` is never called from an automated script — only
  `Lazy! restore`, which installs exactly what `lazy-lock.json` says
  and nothing else.
- No kubeconfig or cluster credentials are mounted into any container.
