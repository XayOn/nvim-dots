# crib profile switcher — source this from .zshrc/.bashrc.
#
# `crib` uses the personal profile, `crib-work` uses work. Each sets
# XDG_CONFIG_HOME only as a prefix on that single command (POSIX
# scoping: a `VAR=val cmd` prefix only affects cmd's environment, never
# the shell's own), so it never leaks into any other command you run —
# crib resolves its global config from $XDG_CONFIG_HOME/crib/config.toml.
crib() {
  XDG_CONFIG_HOME="$HOME/.profiles/personal" command crib "$@"
}

crib-work() {
  XDG_CONFIG_HOME="$HOME/.profiles/work" command crib "$@"
}
