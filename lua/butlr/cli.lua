local M = {}

-- `but` moved --json/--status-after from global flags to per-subcommand flags in
-- 0.20, so they are appended after the subcommand and its positional arguments.
local function build(args, opts)
  local cmd = { "but" }
  vim.list_extend(cmd, args)
  table.insert(cmd, "--json")
  if opts.status_after then
    table.insert(cmd, "--status-after")
  end
  return cmd
end

local function parse_version(str)
  local major, minor, patch = str:match("(%d+)%.(%d+)%.(%d+)")
  if not major then
    return nil
  end
  return { tonumber(major), tonumber(minor), tonumber(patch) }
end

local function cmp_version(a, b)
  for i = 1, 3 do
    local x, y = a[i] or 0, b[i] or 0
    if x ~= y then
      return x < y and -1 or 1
    end
  end
  return 0
end

local version_cache = nil

---@return { raw: string, parts: number[]? }? version, string? err
function M.version()
  if version_cache ~= nil then
    return version_cache.value, version_cache.err
  end
  if vim.fn.executable("but") == 0 then
    version_cache = { err = "`but` executable not found in PATH" }
    return nil, version_cache.err
  end
  local result = vim.system({ "but", "--version" }, { text = true }):wait(5000)
  if result.code ~= 0 then
    version_cache = { err = "`but --version` failed: " .. (result.stderr or "") }
    return nil, version_cache.err
  end
  local raw = vim.trim(result.stdout or "")
  version_cache = { value = { raw = raw, parts = parse_version(raw) } }
  return version_cache.value, nil
end

function M.clear_version_cache()
  version_cache = nil
end

--- Verify the installed `but` is within the version range butlr is written against.
---@return boolean ok, string? msg
function M.check_version()
  local config = require("butlr.config")
  if not config.options.cli.check_version then
    return true, nil
  end

  local version, err = M.version()
  if not version then
    return false, err
  end
  if not version.parts then
    return true, nil
  end

  local min = parse_version(config.options.cli.min_version)
  if min and cmp_version(version.parts, min) < 0 then
    return false,
      ("%s is too old; butlr requires >= %s (CLI flags and subcommands differ)")
        :format(version.raw, config.options.cli.min_version)
  end

  local max = parse_version(config.options.cli.max_tested_version)
  if max and cmp_version({ version.parts[1], version.parts[2], 0 }, { max[1], max[2], 0 }) > 0 then
    return true,
      ("%s is newer than the last tested %s; butlr may be out of date")
        :format(version.raw, config.options.cli.max_tested_version)
  end

  return true, nil
end

---@param args string[]
---@param opts? { cwd?: string, on_success?: fun(data: table), on_error?: fun(err: string), status_after?: boolean }
function M.run(args, opts)
  opts = opts or {}

  vim.system(build(args, opts), { cwd = opts.cwd, text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local err = (result.stderr or "") .. (result.stdout or "")
        if opts.on_error then
          opts.on_error(err)
        else
          vim.notify("[butlr] " .. err, vim.log.levels.ERROR)
        end
        return
      end

      local ok, data = pcall(vim.json.decode, result.stdout)
      if not ok then
        local msg = "failed to parse JSON: " .. (result.stdout or ""):sub(1, 200)
        if opts.on_error then
          opts.on_error(msg)
        else
          vim.notify("[butlr] " .. msg, vim.log.levels.ERROR)
        end
        return
      end

      if opts.on_success then
        opts.on_success(data)
      end
    end)
  end)
end

---@param args string[]
---@param opts? { cwd?: string, status_after?: boolean }
---@return table? data, string? err
function M.run_sync(args, opts)
  opts = opts or {}

  local result = vim.system(build(args, opts), { cwd = opts.cwd, text = true }):wait(5000)
  if result.code ~= 0 then
    return nil, (result.stderr or "") .. (result.stdout or "")
  end

  local ok, data = pcall(vim.json.decode, result.stdout)
  if not ok then
    return nil, "failed to parse JSON"
  end
  return data, nil
end

return M
