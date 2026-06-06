vim.opt.runtimepath:prepend(vim.fn.getcwd())

local calls = {}
local outputs = {}
local current_mode = "n"

local function runner(_, args)
  local key = table.concat(args or {}, " ")
  calls[#calls + 1] = key

  if key == "" then
    local value = table.remove(outputs, 1)
    if type(value) == "table" then
      return value
    end
    return { code = 0, stdout = tostring(value or "1") }
  end

  return { code = 0, stdout = "" }
end

local function reset()
  calls = {}
  outputs = {}
  current_mode = "n"
end

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual))
  end
end

local function assert_calls(expected, message)
  assert_eq(vim.inspect(calls), vim.inspect(expected), message)
end

local plugin = require("in_nvim")

reset()
plugin.setup({
  runner = runner,
  notify = false,
  get_mode = function()
    return { mode = current_mode }
  end,
})
vim.api.nvim_exec_autocmds("InsertEnter", {})
assert_calls({ "-c" }, "first insert defaults to English")

reset()
outputs = { "2" }
vim.api.nvim_exec_autocmds("InsertLeavePre", {})
assert_calls({ "", "-c" }, "leaving insert saves active state and closes")
assert_eq(plugin._state().insert_active, true, "active state should be saved")

reset()
vim.api.nvim_exec_autocmds("InsertEnter", {})
assert_calls({ "-o" }, "entering insert restores active state")

reset()
outputs = { "1" }
vim.api.nvim_exec_autocmds("InsertLeavePre", {})
assert_calls({ "", "-c" }, "leaving insert saves inactive state and closes")
assert_eq(plugin._state().insert_active, false, "inactive state should be saved")

reset()
vim.api.nvim_exec_autocmds("InsertEnter", {})
assert_calls({ "-c" }, "entering insert restores inactive state")

reset()
plugin.setup({
  runner = runner,
  notify = false,
  restore_insert = false,
  get_mode = function()
    return { mode = current_mode }
  end,
})
plugin._state().insert_active = true
vim.api.nvim_exec_autocmds("InsertEnter", {})
assert_calls({ "-c" }, "restore_insert=false always keeps insert English")

reset()
outputs = { { code = 1, stdout = "dbus failed" } }
plugin.setup({
  runner = runner,
  notify = false,
  get_mode = function()
    return { mode = current_mode }
  end,
})
vim.api.nvim_exec_autocmds("InsertLeavePre", {})
assert_eq(plugin._state().insert_active, false, "query failure should fall back to inactive state")

reset()
plugin.setup({
  runner = runner,
  notify = false,
  get_mode = function()
    return { mode = current_mode }
  end,
})
vim.api.nvim_exec_autocmds("FocusGained", {})
assert_calls({ "-c" }, "focus gained in normal mode closes input method")

reset()
current_mode = "i"
plugin._state().insert_active = true
vim.api.nvim_exec_autocmds("FocusGained", {})
assert_calls({ "-o" }, "focus gained in insert mode restores active insert state")

print("in_nvim_spec: OK")
