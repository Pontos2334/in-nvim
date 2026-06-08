# in-nvim

Small Neovim plugin for input method state switching (Fcitx5 and IBus).

## Behavior

- Normal mode keeps the input method inactive (English).
- Insert mode remembers whether the input method was active when you left insert mode.
- Re-entering insert mode restores that active/inactive state.
- Returning focus to Neovim also reapplies the correct state for the current mode.
- Kitty users can install the included watcher so switching back from another
  kitty tab also reapplies the correct state.

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

## Kitty

To restore input state when switching back from another kitty tab, install the
watcher and add it to `kitty.conf`:

```sh
cp extras/kitty/in_nvim_focus.py ~/.config/kitty/in_nvim_focus.py
printf '\nwatcher %s\n' "$HOME/.config/kitty/in_nvim_focus.py" >> ~/.config/kitty/kitty.conf
```

Restart kitty after changing `kitty.conf`.

## Configuration

```lua
require("in_nvim").setup({
  backend = "auto",           -- "auto", "fcitx5", or "ibus"
  command = "fcitx5-remote",  -- fcitx5-remote command
  notify = true,
  restore_insert = true,
  ibus_command = "ibus",            -- ibus command
  ibus_latin_engine = "xkb:us::eng", -- latin engine for IBus deactivation
  kitty_focus_check = true,
  zellij_command = "zellij",
  zellij_focus_check = false,
  zellij_focus_check_interval = 500,
})
```

### Backend selection

`backend = "auto"` (default) detects the available input method framework:
1. If `fcitx5-remote` is on `PATH`, uses Fcitx5.
2. Else if `ibus` is on `PATH` and `ibus engine` can query the current
   engine, uses IBus.
3. Else disables switching and shows one warning with the detected reason.

Set `backend = "fcitx5"` or `backend = "ibus"` to override auto-detection.

`kitty_focus_check = true` starts a small Neovim RPC server when running inside
kitty and writes its address to `/tmp/in-nvim-kitty/<KITTY_WINDOW_ID>`. The kitty
watcher reads this file on focus changes and calls back into Neovim.

`zellij_focus_check = true` keeps the old polling fallback that runs `zellij
action list-panes --json --state`. It is retained for compatibility, but can
cause cursor flicker or redraw noise.

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

Having an IBus input source configured in GNOME is not enough by itself: this
backend needs the `ibus engine` command to work from Neovim's environment. If
`ibus engine` prints `No engine is set` or `Can't connect to IBus`, the plugin
will leave switching disabled instead of pretending that the switch succeeded.

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
