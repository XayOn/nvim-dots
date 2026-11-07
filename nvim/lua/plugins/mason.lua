-- pip-based tools (basedpyright, debugpy, sqlfluff) are venvs bound to the container's python3,
-- so the shared data dir keeps one mason root per python version.
local ok, res = pcall(function()
  return vim.system({ "python3", "-S", "-c", "import sys; print('%d.%d' % sys.version_info[:2])" }):wait()
end)
local py = ok and res.code == 0 and vim.trim(res.stdout) or "none"

return {
  "mason-org/mason.nvim",
  opts = { install_root_dir = vim.fn.stdpath("data") .. "/mason-py" .. py },
}
