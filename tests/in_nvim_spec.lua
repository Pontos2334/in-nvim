vim.opt.runtimepath:prepend(vim.fn.getcwd())

local calls = {}
local outputs = {}
local ibus_calls = {}
local ibus_outputs = {}
local zellij_calls = {}
local zellij_outputs = {}
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

local function ibus_runner(_, args)
  local key = table.concat(args or {}, " ")
  ibus_calls[#ibus_calls + 1] = key

  if key == "engine" then
    local value = table.remove(ibus_outputs, 1)
    if type(value) == "table" then
      return value
    end
    return { code = 0, stdout = tostring(value or "xkb:us::eng") }
  end

  return { code = 0, stdout = "" }
end

local function zellij_runner(_, args)
  zellij_calls[#zellij_calls + 1] = table.concat(args or {}, " ")

  local value = table.remove(zellij_outputs, 1)
  if type(value) == "table" then
    return value
  end

  return { code = 0, stdout = tostring(value or "[]") }
end

local function reset()
  calls = {}
  outputs = {}
  ibus_calls = {}
  ibus_outputs = {}
  zellij_calls = {}
  zellij_outputs = {}
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
  backend = "fcitx5",
  runner = runner,
  notify = false,
  zellij_focus_check = false,
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
  backend = "fcitx5",
  runner = runner,
  notify = false,
  restore_insert = false,
  zellij_focus_check = false,
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
  backend = "fcitx5",
  runner = runner,
  notify = false,
  zellij_focus_check = false,
  get_mode = function()
    return { mode = current_mode }
  end,
})
vim.api.nvim_exec_autocmds("InsertLeavePre", {})
assert_eq(plugin._state().insert_active, false, "query failure should fall back to inactive state")

reset()
plugin.setup({
  backend = "fcitx5",
  runner = runner,
  notify = false,
  zellij_focus_check = false,
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

local old_zellij = vim.env.ZELLIJ
local old_zellij_pane_id = vim.env.ZELLIJ_PANE_ID
vim.env.ZELLIJ = "0"
vim.env.ZELLIJ_PANE_ID = "7"

reset()
plugin.setup({
  backend = "fcitx5",
  runner = runner,
  notify = false,
  zellij_focus_check = "auto",
  zellij_runner = zellij_runner,
  get_mode = function()
    return { mode = current_mode }
  end,
})
assert_eq(plugin._state().zellij_client, nil, "auto should not start zellij polling")

reset()
plugin.setup({
  backend = "fcitx5",
  runner = runner,
  notify = false,
  zellij_focus_check = true,
  zellij_focus_check_interval = 0,
  zellij_runner = zellij_runner,
  get_mode = function()
    return { mode = current_mode }
  end,
})
zellij_outputs = { '[{"id":7,"is_plugin":false,"is_focused":false}]' }
plugin._check_zellij_focus()
assert_calls({}, "hidden zellij pane should not switch input method")

reset()
zellij_outputs = { '[{"id":7,"is_plugin":false,"is_focused":true}]' }
plugin._check_zellij_focus()
assert_calls({ "-c" }, "focused zellij pane in normal mode closes input method")

reset()
current_mode = "i"
plugin._state().zellij_focused = false
plugin._state().insert_active = true
zellij_outputs = { '[{"id":7,"is_plugin":false,"is_focused":true}]' }
plugin._check_zellij_focus()
assert_calls({ "-o" }, "focused zellij pane in insert mode restores active input method")

vim.env.ZELLIJ = old_zellij
vim.env.ZELLIJ_PANE_ID = old_zellij_pane_id

-- IBus backend tests

local function assert_ibus_calls(expected, message)
  assert_eq(vim.inspect(ibus_calls), vim.inspect(expected), message)
end

-- IBus setup + VimEnter: deactivate saves current engine and switches to latin
reset()
ibus_outputs = { "libpinyin" }
plugin.setup({
  backend = "ibus",
  runner = ibus_runner,
  notify = false,
  zellij_focus_check = false,
  get_mode = function()
    return { mode = current_mode }
  end,
})
vim.api.nvim_exec_autocmds("VimEnter", {})
assert_ibus_calls({ "engine", "engine xkb:us::eng" }, "VimEnter deactivates ibus: queries engine then switches to latin")

-- IBus: first InsertEnter with insert_active=false calls deactivate
reset()
current_mode = "i"
vim.api.nvim_exec_autocmds("InsertEnter", {})
assert_ibus_calls({ "engine", "engine xkb:us::eng" }, "first insert defaults to latin for ibus")

-- IBus: leaving insert with active engine saves state
reset()
ibus_outputs = { "libpinyin", "libpinyin" }
current_mode = "n"
vim.api.nvim_exec_autocmds("InsertLeavePre", {})
assert_ibus_calls({ "engine", "engine", "engine xkb:us::eng" }, "leaving insert deactivates ibus")
assert_eq(plugin._state().insert_active, true, "non-latin engine means active state")

-- IBus: entering insert restores active engine
reset()
current_mode = "i"
vim.api.nvim_exec_autocmds("InsertEnter", {})
assert_ibus_calls({ "engine libpinyin" }, "entering insert restores saved ibus engine")

-- IBus: leaving insert with latin engine saves inactive state
reset()
ibus_outputs = { "xkb:us::eng", "xkb:us::eng" }
current_mode = "n"
vim.api.nvim_exec_autocmds("InsertLeavePre", {})
assert_ibus_calls({ "engine", "engine", "engine xkb:us::eng" }, "leaving insert with latin engine still deactivates")
assert_eq(plugin._state().insert_active, false, "latin engine means inactive state")

-- IBus: custom latin engine
reset()
ibus_outputs = { "xkb:de::ger" }
plugin.setup({
  backend = "ibus",
  ibus_latin_engine = "xkb:de::ger",
  runner = ibus_runner,
  notify = false,
  zellij_focus_check = false,
  get_mode = function()
    return { mode = current_mode }
  end,
})
assert_eq(plugin._state().client.latin_engine, "xkb:de::ger", "custom latin engine is set")

print("in_nvim_spec: OK")
