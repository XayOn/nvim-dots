#!/usr/bin/env bash
# Idempotent Neovim setup for inside devcontainers, run by crib's dotfiles
# plugin. Installs Neovim 0.12.x from the official release tarball (not
# apt — Ubuntu/Debian devcontainer base image packages are too old for
# lazy.nvim-based configs), a wrapper that isolates nvim's XDG dirs to
# /nvim/*, uv-managed LSP tools (no Mason), and symlinks nvim/ in this
# repo to ~/.config/nvim.
#
# NOTE: crib's dotfiles plugin runs this as `sh <path>/install.sh`,
# not `./install.sh` — the shebang above is never consulted, so
# without this guard it would execute under plain POSIX sh (dash on
# Debian/Ubuntu), which doesn't understand `pipefail` or
# `${BASH_SOURCE[0]}` below. Confirmed by reading crib's own source
# (internal/plugin/dotfiles/plugin.go), not documented anywhere.
if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NVIM_VERSION="0.12.4"
NVIM_SHA256="012bf3fcac5ade43914df3f174668bf64d05e049a4f032a388c027b1ebd78628"
NVIM_DIST="nvim-linux-x86_64"

# tree-sitter CLI: nvim-treesitter's `main` branch (what LazyVim pins)
# hard-requires this to compile parsers. Normally Mason-installed —
# routed through a direct release download instead. Checksum computed
# locally (upstream doesn't publish one for this asset).
TS_CLI_VERSION="0.26.12"
TS_CLI_SHA256="d00ac0daefc4bf8c4b57842a5c0509927232faad1d83157b64fbad4e2e8d9a8b"

# Node.js: only needed as a delivery mechanism for the three LSPs below
# that ship exclusively as npm packages (no standalone binaries exist).
NODE_VERSION="24.19.0"
NODE_SHA256="14b342e71204f811bde6153be8e04b62aef63c236fef92b55f9c83154b409647"
NODE_DIST="node-v${NODE_VERSION}-linux-x64"

LUA_LS_VERSION="3.19.0"
LUA_LS_SHA256="624ae8dd3bfbd5c2ee3ccf2f3547d33aeefa209971cce8c11d48f69fc1ec065a"

HELM_LS_VERSION="0.5.4"
HELM_LS_SHA256="5d857ba25c461d3218bb98d9e98cb61bc948bfa92b124667d7e6ed695fe2da5f"

# Detected but never required — nvim itself reads this at runtime via
# lua/config/profile.lua. `set -u` above means this must have a default.
DEV_PROFILE="${DEV_PROFILE:-personal}"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }

as_root() {
    if [ "$(id -u)" = "0" ]; then
        "$@"
    else
        sudo "$@"
    fi
}

log "Profile: $DEV_PROFILE"

log "Installing Neovim $NVIM_VERSION to /opt (official tarball, not apt)"
if [ ! -x "/opt/$NVIM_DIST/bin/nvim" ]; then
    tmp_dir="$(mktemp -d)"
    curl -sL -o "$tmp_dir/nvim.tar.gz" \
        "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/${NVIM_DIST}.tar.gz"
    echo "${NVIM_SHA256}  $tmp_dir/nvim.tar.gz" | sha256sum -c -
    as_root tar xzf "$tmp_dir/nvim.tar.gz" -C /opt
    rm -rf "$tmp_dir"
fi

log "Installing tree-sitter CLI $TS_CLI_VERSION (direct binary, not Mason)"
if [ ! -x /usr/local/bin/tree-sitter ]; then
    tmp_dir="$(mktemp -d)"
    curl -sL -o "$tmp_dir/ts.gz" \
        "https://github.com/tree-sitter/tree-sitter/releases/download/v${TS_CLI_VERSION}/tree-sitter-linux-x64.gz"
    echo "${TS_CLI_SHA256}  $tmp_dir/ts.gz" | sha256sum -c -
    gunzip "$tmp_dir/ts.gz"
    as_root install -m 755 "$tmp_dir/ts" /usr/local/bin/tree-sitter
    rm -rf "$tmp_dir"
fi

log "Installing Node.js $NODE_VERSION to /opt (only to carry yamlls/dockerls/bashls npm packages)"
if [ ! -x "/opt/$NODE_DIST/bin/node" ]; then
    tmp_dir="$(mktemp -d)"
    curl -sL -o "$tmp_dir/node.tar.xz" \
        "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_DIST}.tar.xz"
    echo "${NODE_SHA256}  $tmp_dir/node.tar.xz" | sha256sum -c -
    as_root tar xJf "$tmp_dir/node.tar.xz" -C /opt
    rm -rf "$tmp_dir"
fi
# Symlinking node's whole bin/ (not just node/npm/npx) means every
# npm -g installed LSP below lands on PATH automatically, and PATH is
# correct for nvim regardless of whether it's spawned from a login
# shell or not (LSP servers are launched directly by nvim, not through
# a shell that would source .bashrc/.zshrc).
as_root ln -sfn "/opt/$NODE_DIST/bin/node" /usr/local/bin/node
as_root ln -sfn "/opt/$NODE_DIST/bin/npm" /usr/local/bin/npm
as_root ln -sfn "/opt/$NODE_DIST/bin/npx" /usr/local/bin/npx

log "Installing yaml-language-server, dockerfile-language-server-nodejs, bash-language-server (npm, no Mason)"
as_root /usr/local/bin/npm install -g --loglevel=error \
    yaml-language-server \
    dockerfile-language-server-nodejs \
    bash-language-server
for tool in yaml-language-server docker-langserver bash-language-server; do
    as_root ln -sfn "/opt/$NODE_DIST/bin/$tool" "/usr/local/bin/$tool"
done

log "Installing lua-language-server $LUA_LS_VERSION (direct binary, not Mason)"
if [ ! -x "/opt/lua-language-server-${LUA_LS_VERSION}/bin/lua-language-server" ]; then
    tmp_dir="$(mktemp -d)"
    curl -sL -o "$tmp_dir/lls.tar.gz" \
        "https://github.com/LuaLS/lua-language-server/releases/download/${LUA_LS_VERSION}/lua-language-server-${LUA_LS_VERSION}-linux-x64.tar.gz"
    echo "${LUA_LS_SHA256}  $tmp_dir/lls.tar.gz" | sha256sum -c -
    as_root mkdir -p "/opt/lua-language-server-${LUA_LS_VERSION}"
    as_root tar xzf "$tmp_dir/lls.tar.gz" -C "/opt/lua-language-server-${LUA_LS_VERSION}"
    rm -rf "$tmp_dir"
fi
as_root ln -sfn "/opt/lua-language-server-${LUA_LS_VERSION}/bin/lua-language-server" /usr/local/bin/lua-language-server

log "Installing helm-ls $HELM_LS_VERSION (direct binary, not Mason)"
if [ ! -x /usr/local/bin/helm_ls ]; then
    tmp_dir="$(mktemp -d)"
    curl -sL -o "$tmp_dir/helm_ls" \
        "https://github.com/mrjosh/helm-ls/releases/download/v${HELM_LS_VERSION}/helm_ls_linux_amd64"
    echo "${HELM_LS_SHA256}  $tmp_dir/helm_ls" | sha256sum -c -
    as_root install -m 755 "$tmp_dir/helm_ls" /usr/local/bin/helm_ls
    rm -rf "$tmp_dir"
fi

log "Installing nvim-wrapper as /usr/local/bin/nvim"
as_root cp "$REPO_DIR/bin/nvim-wrapper" /usr/local/bin/nvim
as_root chmod +x /usr/local/bin/nvim

log "Creating /nvim/{share,state,cache} and fixing ownership"
# First creation of a mounted volume often lands owned by root — the
# owning user/group must be fixed every run, not just once.
as_root mkdir -p /nvim/share /nvim/state /nvim/cache
as_root chown -R "$(id -u):$(id -g)" /nvim/share /nvim/state /nvim/cache

log "Pre-cloning Kubernetes schemas for kubeschema.nvim"
# kubeschema.nvim only auto-clones this on its first-ever invocation —
# and that on_exit notify callback errors (upstream bug: fires from a
# fast-event context, before it can hand the schema to yamlls), so the
# very first k8s yaml file opened in a fresh container would get no
# completion. Pre-cloning here means that on-demand path (dir already
# exists) never triggers at all.
KUBESCHEMA_DIR="/nvim/share/nvim/kubernetes/schemas"
if [ ! -d "$KUBESCHEMA_DIR" ]; then
    mkdir -p "$(dirname "$KUBESCHEMA_DIR")"
    git clone --depth=1 -q https://github.com/imroc/kubeschemas "$KUBESCHEMA_DIR"
fi

log "Symlinking nvim/ to ~/.config/nvim"
mkdir -p "$HOME/.config"
ln -sfn "$REPO_DIR/nvim" "$HOME/.config/nvim"

log "Installing uv"
if ! command -v uv >/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$HOME/.local/bin:$PATH"

log "Installing basedpyright and ruff via uv (no Mason)"
uv tool install basedpyright --quiet
uv tool install ruff --quiet
# uv installs to ~/.local/bin, which is only on PATH for install.sh's own
# process (and anything sourcing shell rc files) — not for nvim's LSP
# client, which spawns servers inheriting whatever launched nvim. Same
# fix as the npm-installed servers above: symlink into /usr/local/bin.
for tool in basedpyright basedpyright-langserver ruff; do
    as_root ln -sfn "$HOME/.local/bin/$tool" "/usr/local/bin/$tool"
done

log "Restoring plugins from lazy-lock.json (restore, not sync — exact pins only)"
nvim --headless "+Lazy! restore" +qa

log "Done."
