# tmux

Keybindings for `~/.tmux.conf` and `~/.config/nvim/tmux/nvim.conf`.

`Prefix` is `Ctrl-b`: press it, release, then press the key. The same key after `Space` does the same thing in Neovim.

Open these notes with `Prefix ?` in tmux, or `Space ?` then `Tab` in Neovim.

Search them with `/` in the popup, or with `Space K` in Neovim (searches Neovim and tmux keys together).

## Sessions

| Key | Action |
| --- | --- |
| `Prefix s` | Choose session |
| `Prefix $` | Rename session |
| `Prefix d` | Detach |
| `Prefix :` | Command prompt |
| `Prefix r` | Reload `~/.tmux.conf` |

```sh
tmux new -s name        # new named session
tmux ls                 # list sessions
tmux attach -t name     # attach
tmux kill-session -t name
```

## Windows

| Key | Action |
| --- | --- |
| `Prefix c` | New window |
| `Prefix n` / `p` | Next / previous window |
| `Prefix w` | Choose window |
| `Prefix 1` … `9` | Window by number |
| `Prefix ,` | Rename window |
| `Prefix &` | Close window |

## Panes

| Key | Action |
| --- | --- |
| `Prefix h/j/k/l` | Focus left, down, up, right |
| `Prefix V` | Split side by side |
| `Prefix H` | Split top and bottom |
| `Prefix z` | Zoom (toggle) |
| `Prefix x` | Close pane |
| `Prefix Space` | Cycle layouts |
| `Prefix q` | Show pane numbers |
| `Alt-h/j/k/l` | Resize (no prefix) |
| `Prefix t` | Floating terminal (popup) |

## Copy mode

| Key | Action |
| --- | --- |
| `Prefix [` | Enter copy mode |
| `h/j/k/l`, `Ctrl-u` / `Ctrl-d` | Move, half page up / down |
| `/text`, `n` / `N` | Search, next / previous |
| `v` / `V` | Select characters / lines |
| `y` | Copy to system clipboard and exit |
| `Esc` / `q` | Exit |
| `Prefix ]` | Paste |

## Save and restore

| Key | Action |
| --- | --- |
| `Prefix Ctrl-s` | Save sessions (tmux-resurrect) |
| `Prefix Ctrl-r` | Restore sessions |

tmux-continuum also saves every minute and restores when tmux starts.
