local Fcitx5 = require("in_nvim.fcitx5")

local M = {}

local defaults = {
  command = "fcitx5-remote",
  notify = true,
  restore_insert = true,
}

local state = {
  client = nil,
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
    notify_once("Failed to switch Fcitx5 to English. Is fcitx5 running and reachable over DBus?")
  end
end

local function save_insert_state()
  local active, err = state.client:is_active()
  if active == nil then
    notify_once("Failed to query Fcitx5 state: " .. tostring(err))
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
    notify_once("Failed to restore Fcitx5 state. Is fcitx5 running and reachable over DBus?")
  end
end

local function restore_for_current_mode()
  local mode = (M.config.get_mode or vim.api.nvim_get_mode)().mode
  if mode:sub(1, 1) == "i" then
    restore_insert_state()
  else
    deactivate()
  end
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})
  state.client = Fcitx5.new({
    command = M.config.command,
    runner = M.config.runner,
  })
  state.warned = false
  state.insert_active = false

  local group = vim.api.nvim_create_augroup("in_nvim_fcitx5", { clear = true })

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

  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    callback = function()
      restore_for_current_mode()
    end,
  })
end

function M._state()
  return state
end

return M
