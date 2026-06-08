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

local function normalize_result(result)
  if type(result) == "number" then
    return { code = result, stdout = "" }
  end

  if type(result) == "string" then
    return { code = 0, stdout = result }
  end

  return result or {}
end

local function result_error(result)
  local text = result.stderr or result.stdout
  if text and tostring(text) ~= "" then
    return tostring(text)
  end

  return "exit code " .. tostring(result.code or 0)
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

    result = normalize_result(result)
    local code = result.code or 0
    if code ~= 0 then
      return nil, result_error(result)
    end

    return result.stdout or ""
  end

  function self:get_engine()
    local output, err = self:run({ "engine" })
    if not output then
      return nil, err
    end

    local engine = trim(output)
    if engine == "" then
      return nil, "ibus engine returned an empty engine name"
    end

    return engine
  end

  function self:is_active()
    local engine, err = self:get_engine()
    if not engine then
      return nil, err
    end

    return engine ~= self.latin_engine
  end

  function self:set_engine(engine)
    local ok, result = pcall(self.runner, self.command, { "engine", engine })
    if not ok then
      return false, result
    end

    result = normalize_result(result)
    local queried, query_err = self:get_engine()
    if queried == engine then
      return true
    end

    if query_err then
      if (result.code or 0) ~= 0 then
        return false, result_error(result) .. "; verification failed: " .. tostring(query_err)
      end

      return false, "verification failed: " .. tostring(query_err)
    end

    if (result.code or 0) ~= 0 then
      return false, result_error(result) .. "; current engine is " .. tostring(queried)
    end

    return false, "expected engine " .. tostring(engine) .. ", got " .. tostring(queried)
  end

  function self:activate()
    if not self.saved_engine or self.saved_engine == "" then
      return false, "no saved IBus engine to restore"
    end

    return self:set_engine(self.saved_engine)
  end

  function self:deactivate()
    local current, err = self:get_engine()
    if not current then
      return false, err
    end

    if current ~= self.latin_engine then
      self.saved_engine = current
    end

    return self:set_engine(self.latin_engine)
  end

  return self
end

function M.probe(opts)
  local client = M.new(opts)
  local engine, err = client:get_engine()
  if not engine then
    return false, err
  end

  return true
end

return M
