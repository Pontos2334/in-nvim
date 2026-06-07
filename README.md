# in-nvim

Small Neovim plugin for Fcitx5 input-method state switching.

## Behavior

- Normal mode is kept in English by calling `fcitx5-remote -c`.
- Insert mode remembers whether Fcitx5 was active when you left insert mode.
- Re-entering insert mode restores that active/inactive state.
- Returning focus to Neovim also reapplies the correct state for the current mode.
- Zellij users can opt in to an experimental focus fallback, but it is disabled
  by default because polling Zellij can disturb Neovim redraws in some terminals.

The plugin does not modify Fcitx5 source code or your Fcitx5 profile. It only needs `fcitx5-remote` to work inside the Neovim process environment.

## Requirements

- Neovim 0.9 or newer.
- Fcitx5 running in the graphical session.
- `fcitx5-remote` available on `PATH`.
- Fcitx5 DBus addon enabled.
- Optional: `zellij` available on `PATH` for the Zellij focus fallback.

Your current Fcitx5 profile with `keyboard-us` and `pinyin` is enough for the core behavior.

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
  command = "fcitx5-remote",
  notify = true,
  restore_insert = true,
  zellij_command = "zellij",
  zellij_focus_check = false,
  zellij_focus_check_interval = 500,
})
```

`zellij_focus_check = true` polls `zellij action list-panes --json --state`.
Leave it disabled if it causes cursor flicker or redraw noise.

## Troubleshooting

If Neovim shows a DBus or Fcitx5 warning, verify that Fcitx5 is running in the same desktop session:

```sh
fcitx5-remote
fcitx5-remote -n
```

`fcitx5-remote` should print `1` for inactive or `2` for active.

## Tests

```sh
nvim --headless --clean -u NONE -S tests/in_nvim_spec.lua +qa
```
