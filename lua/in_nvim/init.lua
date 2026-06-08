local Backend = require("in_nvim.backend")
local Zellij = require("in_nvim.zellij")

local M = {}

local defaults = {
  backend = "auto",
  command = "fcitx5-remote",
  notify = true,
  restore_insert = true,
  zellij_command = "zellij",
  zellij_focus_check = false,
  zellij_focus_check_interval = 500,
  ibus_command = "ibus",
  ibus_latin_engine = "xkb:us::eng",
}

local state = {
  client = nil,
  zellij_client = nil,
  zellij_focused = nil,
  zellij_timer = nil,
  warned = false,
  insert_active = false,
}

local function notify_once(message)
  if state.warned or not M.config.notify then
    return
  end

  state.warned = true
  vim.schedule(function()
    vim.notify(message, vim.log.levels.WARN, { title = "in-nvim" })
  end)
end

local function deactivate()
  local ok = state.client:deactivate()
  if not ok then
    notify_once("Failed to deactivate input method. Is the input method running?")
  end
end

local function save_insert_state()
  local active, err = state.client:is_active()
  if active == nil then
    notify_once("Failed to query input method state: " .. tostring(err))
    state.insert_active = false
    return
  end

  state.insert_active = active
end

local function restore_insert_state()
  if not M.config.restore_insert then
    deactivate()
    return
  end

  local ok
  if state.insert_active then
    ok = state.client:activate()
  else
    ok = state.client:deactivate()
  end

  if not ok then
    notify_once("Failed to restore input method state. Is the input method running?")
  end
end

local function restore_for_current_mode()
  local mode = (M.config.get_mode or vim.api.nvim_get_mode)().mode
  if mode:sub(1, 1) == "i" or mode == "t" then
    restore_insert_state()
  else
    deactivate()
  end
end

local function stop_zellij_focus_check()
  if not state.zellij_timer then
    return
  end

  state.zellij_timer:stop()
  if not state.zellij_timer:is_closing() then
    state.zellij_timer:close()
  end
  state.zellij_timer = nil
end

local function zellij_focus_check_enabled()
  return M.config.zellij_focus_check == true
end

local function check_zellij_focus()
  if not state.zellij_client then
    return
  end

  local focused = state.zellij_client:is_pane_focused(vim.env.ZELLIJ_PANE_ID)
  if focused == nil then
    return
  end

  local was_focused = state.zellij_focused
  state.zellij_focused = focused

  if focused and was_focused ~= true then
    restore_for_current_mode()
  end
end

local function start_zellij_focus_check()
  stop_zellij_focus_check()

  state.zellij_client = nil
  state.zellij_focused = nil

  if not zellij_focus_check_enabled() then
    return
  end

  state.zellij_client = Zellij.new({
    command = M.config.zellij_command,
    runner = M.config.zellij_runner,
  })

  local interval = tonumber(M.config.zellij_focus_check_interval) or 0
  if interval <= 0 then
    return
  end

  local uv = vim.uv or vim.loop
  state.zellij_timer = uv.new_timer()
  state.zellij_timer:start(
    interval,
    interval,
    vim.schedule_wrap(function()
      check_zellij_focus()
    end)
  )

  if state.zellij_timer.unref then
    state.zellij_timer:unref()
  end
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})
  state.client = Backend.resolve(M.config)
  state.warned = false
  state.insert_active = false

  local group = vim.api.nvim_create_augroup("in_nvim_fcitx5", { clear = true })
  start_zellij_focus_check()

  if vim.v.vim_did_enter == 1 then
    deactivate()
  else
    vim.api.nvim_create_autocmd("VimEnter", {
      group = group,
      callback = function()
        deactivate()
      end,
    })
  end

  vim.api.nvim_create_autocmd("InsertLeavePre", {
    group = group,
    callback = function()
      save_insert_state()
      deactivate()
    end,
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function()
      restore_insert_state()
    end,
  })

  vim.api.nvim_create_autocmd("TermEnter", {
    group = group,
    callback = function()
      restore_insert_state()
    end,
  })

  vim.api.nvim_create_autocmd("TermLeave", {
    group = group,
    callback = function()
      save_insert_state()
      deactivate()
    end,
  })

  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    callback = function()
      restore_for_current_mode()
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      stop_zellij_focus_check()
    end,
  })
end

function M._state()
  return state
end

function M._check_zellij_focus()
  check_zellij_focus()
end

return M
