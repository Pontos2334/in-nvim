# in-nvim

Small Neovim plugin for input method state switching (Fcitx5 and IBus).

## Behavior

- Normal mode keeps the input method inactive (English).
- Insert mode remembers whether the input method was active when you left insert mode.
- Re-entering insert mode restores that active/inactive state.
- Returning focus to Neovim also reapplies the correct state for the current mode.
- Zellij users can opt in to an experimental focus fallback, but it is disabled
  by default because polling Zellij can disturb Neovim redraws in some terminals.

## Requirements

- Neovim 0.9 or newer.
- One of:
  - **Fcitx5**: running in the graphical session with `fcitx5-remote` on `PATH`.
  - **IBus**: running with `ibus` on `PATH`.
- Optional: `zellij` available on `PATH` for the Zellij focus fallback.

## LazyVim

Create a plugin spec in `~/.config/nvim/lua/plugins/in-nvim.lua`:

```lua
return {
  "Pontos2334/in-nvim",
  name = "in-nvim",
  config = function()
    require("in_nvim").setup()
  end,
}
```

## Configuration

```lua
require("in_nvim").setup({
  backend = "auto",           -- "auto", "fcitx5", or "ibus"
  command = "fcitx5-remote",  -- fcitx5-remote command
  notify = true,
  restore_insert = true,
  ibus_command = "ibus",            -- ibus command
  ibus_latin_engine = "xkb:us::eng", -- latin engine for IBus deactivation
  zellij_command = "zellij",
  zellij_focus_check = false,
  zellij_focus_check_interval = 500,
})
```

### Backend selection

`backend = "auto"` (default) detects the available input method framework:
1. If `fcitx5-remote` is on `PATH`, uses Fcitx5.
2. Else if `ibus` is on `PATH`, uses IBus.
3. Else falls back to Fcitx5 (will show a warning).

Set `backend = "fcitx5"` or `backend = "ibus"` to override auto-detection.

`zellij_focus_check = true` polls `zellij action list-panes --json --state`.
Leave it disabled if it causes cursor flicker or redraw noise.

## Troubleshooting

### Fcitx5

If Neovim shows a DBus or Fcitx5 warning, verify that Fcitx5 is running in the same desktop session:

```sh
fcitx5-remote
fcitx5-remote -n
```

`fcitx5-remote` should print `1` for inactive or `2` for active.

### IBus

Verify that IBus is running and the daemon is accessible:

```sh
ibus engine
```

This should print the current engine name (e.g., `xkb:us::eng` or `libpinyin`).

If `ibus_latin_engine` does not match your layout, set it to your Latin engine name:

```lua
require("in_nvim").setup({
  backend = "ibus",
  ibus_latin_engine = "xkb:de::ger", -- example for German layout
})
```

## Tests

```sh
nvim --headless --clean -u NONE -S tests/in_nvim_spec.lua +qa
```
