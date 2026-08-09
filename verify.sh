#!/usr/bin/env bash
# Acceptance checks for phases 1, 3, and 4. Phase 2 is intentionally not
# scripted here (its acceptance is "open these files, observe LSP
# behavior" — see README) but was verified manually during development.
#
# Requires: docker, and (for phase 3) crib installed + shell/crib-profiles.sh
# sourced. Spins up and tears down real containers/volumes — safe to
# re-run, but not free (pulls/builds happen each run).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="mcr.microsoft.com/devcontainers/base:ubuntu"
FAILED=0

pass() { printf '\033[1;32mPASS\033[0m %s\n' "$1"; }
fail() {
    printf '\033[1;31mFAIL\033[0m %s\n' "$1"
    FAILED=1
}

echo "== Phase 1: install.sh + checkhealth (invoked as \`sh\`, matching crib's dotfiles plugin) =="
out="$(mktemp)"
if docker run --rm -v "$REPO_DIR:/dots" "$IMAGE" \
    bash -c "sh /dots/install.sh && nvim --headless '+checkhealth' +qa" >"$out" 2>&1; then
    pass "phase 1: install.sh + checkhealth exits 0"
else
    fail "phase 1: install.sh + checkhealth (see $out)"
fi

echo
echo "== Phase 3: crib profiles use distinct volumes and identities =="
if command -v crib >/dev/null && [ -f "$REPO_DIR/shell/crib-profiles.sh" ]; then
    # shellcheck disable=SC1091
    source "$REPO_DIR/shell/crib-profiles.sh"

    proj_a="$(mktemp -d)"
    proj_b="$(mktemp -d)"
    mkdir -p "$proj_a/.devcontainer" "$proj_b/.devcontainer"
    printf '{"name":"verify-a","image":"%s"}\n' "$IMAGE" > "$proj_a/.devcontainer/devcontainer.json"
    printf '{"name":"verify-b","image":"%s"}\n' "$IMAGE" > "$proj_b/.devcontainer/devcontainer.json"

    (cd "$proj_a" && crib up >/dev/null 2>&1) || true
    (cd "$proj_b" && crib-work up >/dev/null 2>&1) || true

    vol_count="$(docker volume ls -q | grep -c '^crib-nvim-.*-\(personal\|work\)$' || true)"
    if [ "$vol_count" -ge 6 ]; then
        pass "phase 3: distinct personal/work volumes exist ($vol_count found)"
    else
        fail "phase 3: expected >=6 crib-nvim-*-{personal,work} volumes, found $vol_count"
    fi

    ident_a="$(cd "$proj_a" && crib run -- git var GIT_AUTHOR_IDENT 2>/dev/null || true)"
    ident_b="$(cd "$proj_b" && crib-work run -- git var GIT_AUTHOR_IDENT 2>/dev/null || true)"
    if [ -n "$ident_a" ] && [ -n "$ident_b" ]; then
        pass "phase 3: git identity resolves in both profiles"
        echo "  personal: $ident_a"
        echo "  work:     $ident_b"
    else
        fail "phase 3: git identity did not resolve (personal='$ident_a' work='$ident_b')"
    fi

    (cd "$proj_a" && crib remove --force >/dev/null 2>&1) || true
    (cd "$proj_b" && crib-work remove --force >/dev/null 2>&1) || true
    for v in personal work; do
        docker volume rm "crib-nvim-share-$v" "crib-nvim-state-$v" "crib-nvim-cache-$v" >/dev/null 2>&1 || true
    done
    rm -rf "$proj_a" "$proj_b"
else
    fail "phase 3: crib not on PATH or shell/crib-profiles.sh missing — skipped"
fi

echo
echo "== Phase 4: /nvim/* paths work unchanged across remoteUser (root, vscode) =="
for user in root vscode; do
    share_vol="verify-nvim-share-$user"
    state_vol="verify-nvim-state-$user"
    cache_vol="verify-nvim-cache-$user"
    docker volume create "$share_vol" >/dev/null
    docker volume create "$state_vol" >/dev/null
    docker volume create "$cache_vol" >/dev/null

    out="$(mktemp)"
    if docker run --rm -v "$REPO_DIR:/dots" \
        -v "$share_vol:/nvim/share" -v "$state_vol:/nvim/state" -v "$cache_vol:/nvim/cache" \
        -u "$user" "$IMAGE" \
        bash -c "sh /dots/install.sh && nvim --headless '+checkhealth' +qa" >"$out" 2>&1; then
        pass "phase 4: remoteUser=$user"
    else
        fail "phase 4: remoteUser=$user (see $out)"
    fi
    docker volume rm "$share_vol" "$state_vol" "$cache_vol" >/dev/null 2>&1 || true
done

echo
echo "NOTE: only root and vscode were tested — this image has no 'node'"
echo "user. A javascript-node-based image would be the natural third case."

if [ "$FAILED" -eq 0 ]; then
    echo
    echo "All checks passed."
else
    echo
    echo "Some checks failed — see output above."
    exit 1
fi
