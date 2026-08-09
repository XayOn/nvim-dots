#!/usr/bin/env bash
# Idempotent Neovim setup for inside devcontainers, run by crib's dotfiles
# plugin. Installs Neovim 0.12.x from the official release tarball (not
# apt — Ubuntu/Debian devcontainer base image packages are too old for
# lazy.nvim-based configs), a wrapper that isolates nvim's XDG dirs to
# /nvim/*, uv-managed LSP tools (no Mason), and symlinks nvim/ in this
# repo to ~/.config/nvim.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NVIM_VERSION="0.12.4"
NVIM_SHA256="012bf3fcac5ade43914df3f174668bf64d05e049a4f032a388c027b1ebd78628"
NVIM_DIST="nvim-linux-x86_64"

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

log "Installing nvim-wrapper as /usr/local/bin/nvim"
as_root cp "$REPO_DIR/bin/nvim-wrapper" /usr/local/bin/nvim
as_root chmod +x /usr/local/bin/nvim

log "Creating /nvim/{share,state,cache} and fixing ownership"
# First creation of a mounted volume often lands owned by root — the
# owning user/group must be fixed every run, not just once.
as_root mkdir -p /nvim/share /nvim/state /nvim/cache
as_root chown -R "$(id -u):$(id -g)" /nvim/share /nvim/state /nvim/cache

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

log "Restoring plugins from lazy-lock.json (restore, not sync — exact pins only)"
nvim --headless "+Lazy! restore" +qa

log "Done."
