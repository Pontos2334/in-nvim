local M = {}

local function new_noop(reason)
  local self = {
    reason = reason,
  }

  function self:is_active()
    return nil, self.reason
  end

  function self:activate()
    return false, self.reason
  end

  function self:deactivate()
    return false, self.reason
  end

  return self
end

function M.detect(config)
  config = config or {}

  if vim.fn.executable(config.command or "fcitx5-remote") == 1 then
    return "fcitx5"
  end

  local ibus_command = config.ibus_command or "ibus"
  if vim.fn.executable(ibus_command) == 1 then
    local IBus = require("in_nvim.ibus")
    local ok, err = IBus.probe({
      command = ibus_command,
      runner = config.runner,
      latin_engine = config.ibus_latin_engine,
    })
    if ok then
      return "ibus"
    end

    return nil, "IBus is installed but not usable: " .. tostring(err)
  end

  return nil, "no usable input method backend found"
end

function M.resolve(config)
  config = config or {}

  local backend_name = config.backend or "auto"
  if backend_name == "auto" then
    local err
    backend_name, err = M.detect(config)
    if not backend_name then
      return new_noop(err), err
    end
  end

  if backend_name == "fcitx5" then
    local Fcitx5 = require("in_nvim.fcitx5")
    return Fcitx5.new({
      command = config.command or "fcitx5-remote",
      runner = config.runner,
    })
  end

  if backend_name == "ibus" then
    local IBus = require("in_nvim.ibus")
    return IBus.new({
      command = config.ibus_command or "ibus",
      runner = config.runner,
      latin_engine = config.ibus_latin_engine,
    })
  end

  local err = "unknown backend: " .. tostring(backend_name)
  return new_noop(err), err
end

return M
