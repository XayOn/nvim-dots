-- Reads DEV_PROFILE (set by crib's [workspace].env per profile, see
-- ~/.profiles/{personal,work}/crib/config.toml) so plugin specs can
-- gate anything that shouldn't run in a work container.
local name = vim.env.DEV_PROFILE or "personal"

return {
  name = name,
  is_work = name == "work",
}
