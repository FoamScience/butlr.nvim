local M = {}

---@param args string[]
---@param opts? { cwd?: string, on_success?: fun(data: table), on_error?: fun(err: string), status_after?: boolean }
function M.run(args, opts)
  opts = opts or {}
  local cmd = { "but", "-j" }
  if opts.status_after then
    table.insert(cmd, "--status-after")
  end
  vim.list_extend(cmd, args)

  vim.system(cmd, { cwd = opts.cwd, text = true }, function(result)
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
---@param opts? { cwd?: string }
---@return table? data, string? err
function M.run_sync(args, opts)
  opts = opts or {}
  local cmd = { "but", "-j" }
  vim.list_extend(cmd, args)

  local result = vim.system(cmd, { cwd = opts.cwd, text = true }):wait(5000)
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
