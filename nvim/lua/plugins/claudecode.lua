-- LazyVim extra only lazy-loads on keys; also load on :ClaudeCode* commands
return {
  "coder/claudecode.nvim",
  cmd = { "ClaudeCode", "ClaudeCodeFocus", "ClaudeCodeSend", "ClaudeCodeAdd", "ClaudeCodeTreeAdd", "ClaudeCodeDiffAccept", "ClaudeCodeDiffDeny" },
}
