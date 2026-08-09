# Notes: things crib's docs didn't cover

Everything below was discovered empirically (reading crib's Go source,
or hitting it live) — none of it is documented on
https://fgrehm.github.io/crib/, at least not as of crib v0.9.1.

## crib runs install scripts as `sh <path>`, not `./<path>`

The dotfiles plugin's auto-detect (`internal/plugin/dotfiles/plugin.go`)
runs:

```go
runCmd := []string{"sh", scriptPath}
```

Not `exec scriptPath` and not `sh -c scriptPath`. This means the
script's own shebang line is **never consulted** — it always runs
under whatever `sh` actually is (`dash` on Debian/Ubuntu), regardless
of what the shebang says. `install.sh` has a `#!/usr/bin/env bash`
shebang and uses `set -euo pipefail` and `${BASH_SOURCE[0]}`, both
bash-only. Under real `sh` this doesn't error loudly — `pipefail` is
just silently rejected or ignored depending on the shell, and
`BASH_SOURCE` expands to nothing, breaking `REPO_DIR` computation
silently.

Fix used here — a portable re-exec guard as the very first real line:

```sh
if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi
```

Any dotfiles install script targeting crib needs this same guard (or
to just be written in POSIX sh from the start).

## The dotfiles plugin fails open on clone errors

If `git clone` fails (bad URL, no network, auth failure), the plugin
logs a `WARN` and returns `nil, nil` — it does **not** fail `crib up`.
Confirmed live with a deliberately-unreachable placeholder repo: `crib
up` completed successfully, container came up, `[workspace].env` and
`.mount` were applied normally. Convenient for iterating on configs
before a dotfiles repo is actually pushed anywhere, but also means a
silently-broken dotfiles URL won't be obvious from `crib up`'s exit
code — check `crib logs` / stderr if the dotfiles install doesn't
seem to have run.

## Global config path — confirmed, not just documented

The docs say crib "respects `$XDG_CONFIG_HOME`" for
`~/.config/crib/config.toml` but don't spell out the exact composed
path. Confirmed by setting `XDG_CONFIG_HOME=/tmp/crib-xdg-test`,
putting `[workspace].env = { TEST_XDG_MARKER = "..." }` in
`$XDG_CONFIG_HOME/crib/config.toml`, running `crib up`, and checking
the container's environment — the var was there. Path is exactly
`$XDG_CONFIG_HOME/crib/config.toml`.

## `[workspace].mount` syntax

Matches Docker's `--mount` flag format exactly (confirmed from
`internal/config/types.go`'s `ParseMount`):

```
type=volume,source=<name>,target=<path>
type=bind,source=<host-path>,target=<path>
```

## LazyVim's core LSP loader already uses `vim.lsp.config()`/`vim.lsp.enable()`

`lazyvim/plugins/lsp/init.lua` does not call
`require('lspconfig').X.setup{}` — it calls `vim.lsp.config(server,
opts)` and `vim.lsp.enable(server)` directly. Good news for a
"no lspconfig.setup" requirement. The catch: **Mason is still an
unavoidable core dependency** of `nvim-lspconfig` in LazyVim
(`mason.nvim` + `mason-lspconfig.nvim` are both pulled in
unconditionally), and any server present in `opts.servers` gets
routed through `mason-lspconfig.setup({ automatic_enable = ... })`
*unless* you set `mason = false` on that server's entry. Removing the
Mason plugins outright isn't practical without forking LazyVim's core
spec — the workable middle ground is `mason = false` per server (see
`lua/plugins/lsp.lua`) plus a **function**-based `opts` override on
`mason.nvim` itself to force `ensure_installed = {}` (a plain table
opts won't reliably clear the list — `vim.tbl_deep_extend` doesn't
merge Lua arrays element-wise across multiple specs; LazyVim's own
starter template has a comment about exactly this).

## `nvim-treesitter`'s `main` branch needs the tree-sitter CLI

LazyVim currently pins `nvim-treesitter` on its `main` (rewrite)
branch, which hard-requires the `tree-sitter` CLI binary to compile
parsers from source — normally Mason-installed
(`ensure_installed = {"tree-sitter-cli"}` from LazyVim core, not any
extra). Routed through a direct release binary download in
`install.sh` instead, same as everything else.

## Three LSPs are npm-only, no standalone binaries

`yaml-language-server`, `dockerfile-language-server-nodejs`, and
`bash-language-server` ship only as npm packages — no GitHub release
binaries exist for any of them. `install.sh` bootstraps a minimal
Node.js from the official release tarball purely to carry these three
via `npm install -g`, then symlinks the resulting binaries
(`yaml-language-server`, `docker-langserver`, `bash-language-server` —
note the second one's binary name doesn't match its package name)
into `/usr/local/bin`.

## `uv tool install` binaries aren't on PATH for LSP servers

`uv tool install` puts binaries in `~/.local/bin` and only updates
`PATH` for shells that source its shell-init snippet. Neovim's LSP
client spawns servers by inheriting whatever environment launched
`nvim` — not a login shell, so `~/.local/bin` often isn't there.
Symlinked `basedpyright`, `basedpyright-langserver`, and `ruff` into
`/usr/local/bin` explicitly, same fix as the npm-installed servers.

## kubeschema.nvim's first-run schema clone breaks its own callback

`kubeschema.nvim`'s `ensure_schema_dir()` (in `lua/kubeschema/init.lua`)
clones `imroc/kubeschemas` via a `plenary.job` and calls `vim.notify`
in that job's `on_exit` callback. `on_exit` runs in a libuv "fast
event" context, and `vim.notify` → `nvim_echo` throws `E5560: nvim_echo
must not be called in a fast event context` there — an upstream bug.
The `git clone` itself isn't affected (it's a separate process), but
the crash means the schema never gets attached to yamlls for that
buffer, so completion silently returns nothing on a project's first-
ever Kubernetes yaml file in a fresh container.

Worked around by pre-cloning the schema repo directly in `install.sh`
(`git clone --depth=1 https://github.com/imroc/kubeschemas
/nvim/share/nvim/kubernetes/schemas`) — `ensure_schema_dir()` only
triggers its own clone-and-notify path when the directory doesn't
already exist, so this sidesteps the bug entirely rather than fixing
it.

## Testing pitfall worth flagging for future maintainers

When testing with `docker run -v host_path:/container_path` and the
container path doesn't match what a test script references,
`vim.cmd("edit /wrong/path")` does **not** error — Neovim creates an
empty, unsaved buffer with that name (completely valid behavior for
opening a not-yet-existing file). An LSP client will happily attach to
it (filetype detection just needs the extension) and report zero
diagnostics, which looks identical to "LSP attached but broken."
Burned a fair amount of time here chasing pull-vs-push diagnostics and
`root_dir` theories that turned out to be chasing a phantom empty
buffer — always double check the mount's target path matches exactly
what the test script opens.
