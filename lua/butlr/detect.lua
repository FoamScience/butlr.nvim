local M = {}

---@type table<string, boolean>
local cache = {}

function M.is_gitbutler(force)
  local cwd = vim.uv.cwd()
  if not force and cache[cwd] ~= nil then
    return cache[cwd]
  end
  local git_dir = vim.fs.find(".git", { path = cwd, upward = true, type = "directory" })[1]
  if not git_dir then
    cache[cwd] = false
    return false
  end
  local toml = vim.fs.joinpath(git_dir, "gitbutler", "virtual_branches.toml")
  cache[cwd] = vim.uv.fs_stat(toml) ~= nil
  return cache[cwd]
end

function M.clear_cache()
  cache = {}
end

return M
