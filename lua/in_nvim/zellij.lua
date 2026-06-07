local M = {}

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

function M.new(opts)
  opts = opts or {}

  local self = {
    command = opts.command or "zellij",
    runner = opts.runner or default_runner,
  }

  function self:run(args)
    local ok, result = pcall(self.runner, self.command, args or {})
    if not ok then
      return nil, result
    end

    result = normalize_result(result)
    local code = result.code or 0
    if code ~= 0 then
      return nil, result.stderr or result.stdout or ("exit code " .. code)
    end

    return result.stdout or ""
  end

  function self:is_pane_focused(pane_id)
    pane_id = tostring(pane_id or "")
    if pane_id == "" then
      return nil, "missing pane id"
    end

    local output, err = self:run({ "action", "list-panes", "--json", "--state" })
    if not output then
      return nil, err
    end

    local ok, panes = pcall(vim.fn.json_decode, output)
    if not ok or type(panes) ~= "table" then
      return nil, "invalid zellij pane list"
    end

    for _, pane in ipairs(panes) do
      local id = tostring(pane.id or "")
      if id == pane_id or ("terminal_" .. id) == pane_id then
        return pane.is_focused == true
      end
    end

    return nil, "pane not found"
  end

  return self
end

return M
