local M = {}

local function trim(value)
  return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function default_runner(command, args)
  local output = vim.fn.systemlist(vim.list_extend({ command }, args or {}))

  return {
    code = vim.v.shell_error,
    stdout = table.concat(output, "\n"),
  }
end

function M.new(opts)
  opts = opts or {}

  local self = {
    command = opts.command or "fcitx5-remote",
    runner = opts.runner or default_runner,
  }

  function self:run(args)
    local ok, result = pcall(self.runner, self.command, args or {})
    if not ok then
      return nil, result
    end

    if type(result) == "number" then
      result = { code = result, stdout = "" }
    elseif type(result) == "string" then
      result = { code = 0, stdout = result }
    end

    result = result or {}
    local code = result.code or 0
    if code ~= 0 then
      return nil, result.stderr or result.stdout or ("exit code " .. code)
    end

    return result.stdout or ""
  end

  function self:is_active()
    local output, err = self:run({})
    if not output then
      return nil, err
    end

    return trim(output) == "2"
  end

  function self:activate()
    return self:run({ "-o" }) ~= nil
  end

  function self:deactivate()
    return self:run({ "-c" }) ~= nil
  end

  return self
end

return M
