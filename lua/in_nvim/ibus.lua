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
    command = opts.command or "ibus",
    runner = opts.runner or default_runner,
    latin_engine = opts.latin_engine or "xkb:us::eng",
    saved_engine = nil,
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
    local output, err = self:run({ "engine" })
    if not output then
      return nil, err
    end

    return trim(output) ~= self.latin_engine
  end

  function self:activate()
    if not self.saved_engine or self.saved_engine == "" then
      return false
    end

    -- ibus engine <name> may return non-zero exit code even on success
    self:run({ "engine", self.saved_engine })
    return true
  end

  function self:deactivate()
    local output = self:run({ "engine" })
    if output then
      local current = trim(output)
      if current ~= self.latin_engine then
        self.saved_engine = current
      end
    end

    self:run({ "engine", self.latin_engine })
    return true
  end

  return self
end

return M
