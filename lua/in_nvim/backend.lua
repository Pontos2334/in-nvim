local M = {}

function M.detect()
  if vim.fn.executable("fcitx5-remote") == 1 then
    return "fcitx5"
  end

  if vim.fn.executable("ibus") == 1 then
    return "ibus"
  end

  return "fcitx5"
end

function M.resolve(config)
  config = config or {}

  local backend_name = config.backend or "auto"
  if backend_name == "auto" then
    backend_name = M.detect()
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

  return nil, "unknown backend: " .. tostring(backend_name)
end

return M
