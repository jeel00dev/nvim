# Neovim configuration

A small Neovim setup for Python and C++ that runs alongside tmux without key clashes.

## Requirements

- Neovim 0.11 or newer (tested on 0.11.7 and 0.12.5)
- `git`, `rg`, `fzf`
- Optional: `basedpyright`, `ruff`, `clangd`, `clang-format`, `stylua`, `shfmt`, `jq`
- A true-colour terminal (kitty) for the start screen

## Install

```sh
git clone <this repo> ~/.config/nvim
nvim                                   # lazy.nvim installs the locked plugins
:TSInstall python cpp c lua bash json markdown markdown_inline
```

Add this line to `~/.tmux.conf`:

```tmux
source-file -q ~/.config/nvim/tmux/nvim.conf
```

## Keys

tmux uses `Ctrl-b` + key. Neovim uses `Space` + the same key for the same action.

- [docs/nvim.md](docs/nvim.md): Neovim keys, opened with `Space ?`; `Space K` searches all keys
- [docs/tmux.md](docs/tmux.md): tmux keys, opened with `Prefix ?` (or `Tab` in the Neovim notes)

Every global Neovim mapping is defined in [lua/config/keymaps.lua](lua/config/keymaps.lua).

## Layout

| Path | Contents |
| --- | --- |
| `init.lua` | Load order |
| `lua/config/options.lua` | Options and autocommands |
| `lua/config/keymaps.lua` | All keymaps |
| `lua/config/plugins.lua` | Plugins (lazy.nvim) |
| `lua/config/lsp.lua` | Diagnostics, language servers, completion |
| `lsp/` | basedpyright, ruff and clangd settings |
| `lua/config/statusline.lua` | Statusline |
| `lua/config/notes.lua` | Notes viewer and key search |
| `lua/config/terminal.lua` | Floating terminal |
| `lua/config/notify.lua` | Toast notifications |
| `lua/config/dashboard.lua` | Start screen driver |
| `lua/config/interstellar.lua` | Start-screen renderer (background, colour, output) |
| `lua/config/interstellar_scenes.lua` | Black hole and quasar scenes |
| `lua/config/interstellar_ship.lua` | Endurance renderer |
| `colors/personal.lua`, `lua/theme/palette.lua` | Colour scheme |
| `tmux/nvim.conf` | tmux settings for use with Neovim |

## Plugins

lazy.nvim, nvim-treesitter, fzf-lua, nvim-tree, gitsigns, conform, nvim-autopairs, which-key.
