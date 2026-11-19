# Neovim

Keybindings for this configuration. `Space` is the leader key.

Open these notes with `Space ?` and press `Tab` to switch to the tmux notes.

Search every key in both notes with `Space K` (or `s` inside the notes). Enter opens the matching row.

## Same keys as tmux

tmux uses `Ctrl-b` then a key. Neovim uses `Space` then the same key.

| tmux | Neovim | Action |
| --- | --- | --- |
| `Ctrl-b h/j/k/l` | `Space h/j/k/l` | Focus pane / split left, down, up, right |
| `Ctrl-b V` | `Space V` | Split side by side |
| `Ctrl-b H` | `Space H` | Split top and bottom |
| `Ctrl-b z` | `Space z` | Zoom (toggle) |
| `Ctrl-b x` | `Space x` | Close pane / split |
| `Ctrl-b c` | `Space c` | New window / buffer |
| `Ctrl-b n` / `p` | `Space n` / `p` | Next / previous window / buffer |
| `Ctrl-b w` | `Space w` | Choose window / buffer |
| `Ctrl-b &` | `Space &` | Close window / buffer |
| `Ctrl-b t` | `Space t` | Floating terminal |
| `Ctrl-b ?` | `Space ?` | Notes |
| `Alt-h/j/k/l` | `Alt-Left/Down/Up/Right` | Resize |

## Terminal

| Key | Action |
| --- | --- |
| `Space t` | Show / hide the floating terminal |
| `Alt-t` | Show / hide from any mode, including inside the terminal |
| `Esc Esc` | Normal mode in the terminal (scroll, copy); `i` goes back |
| `q` (Normal mode) | Hide the terminal |

The shell keeps running while hidden. `exit` closes it.

## Find

| Key | Action |
| --- | --- |
| `Space K` | Search all keys (Neovim and tmux) |
| `Space f` | Find file |
| `Space r` | Recent files |
| `Space /` | Search text in project |
| `Space *` | Search word under cursor in project |
| `Space s` | Symbols in file |
| `Space d` | Diagnostics in project |
| `Space e` | File tree |
| `Space q` | Quickfix list (toggle) |

In a picker: `Enter` open, `Ctrl-v` / `Ctrl-s` open in split, `Tab` select, `Ctrl-q` send to Quickfix, `Esc` close.

In the file tree: `Enter` open, `a` create, `d` delete, `r` rename, `g?` all tree keys.

## Code

| Key | Action |
| --- | --- |
| `K` | Documentation |
| `gd` | Definition |
| `grr` | References |
| `gri` | Implementations |
| `grt` | Type definition |
| `grn` | Rename |
| `gra` | Code action |
| `]d` / `[d` | Next / previous diagnostic |
| `Ctrl-w d` | Diagnostic under cursor |
| `Space =` | Format file or selection |
| `Ctrl-o` / `Ctrl-i` | Jump back / forward |

Files are formatted on save. `:FormatToggle` turns that off and on.

## Completion

| Key | Action |
| --- | --- |
| `Ctrl-Space` | Show completion |
| `Tab` / `Shift-Tab` | Next / previous item, or jump in a snippet |
| `Ctrl-y` | Accept |
| `Ctrl-e` | Dismiss |
| `Ctrl-s` | Signature help |
| `Ctrl-x Ctrl-f` | Complete a file path |

## Git

| Key | Action |
| --- | --- |
| `]c` / `[c` | Next / previous change |
| `Space g` | Preview change |
| `Space b` | Blame line |

## Lists

| Key | Action |
| --- | --- |
| `]q` / `[q` | Next / previous Quickfix item |
| `]b` / `[b` | Next / previous buffer |
| `Ctrl-^` | Alternate buffer |

## Move and edit

| Key | Action |
| --- | --- |
| `j` / `k` | Down / up a line, keeping the cursor centred |
| `w` / `b` / `e` | Next word / previous word / end of word |
| `0` / `^` / `$` | Line start / first character / line end |
| `gg` / `G` / `42G` | First line / last line / line 42 |
| `Ctrl-d` / `Ctrl-u` | Half page down / up, keeping the cursor centred |
| `%` | Matching bracket |
| `u` / `Ctrl-r` / `.` | Undo / redo / repeat |
| `>` / `<` (Visual) | Indent / unindent, keep selection |
| `zo` / `zc` / `za` | Open / close / toggle fold |
| `:w` / `:q` / `:wq` | Save / close / save and close |

## Select

`v` selects characters, `V` lines, `Ctrl-v` a block. Text objects work with `v`, `y`, `d` and `c`.

| Key | Selects |
| --- | --- |
| `iw` / `aw` | Word / word and space |
| `i"` / `a"` | Inside / around double quotes |
| `i'` / `a'` | Inside / around single quotes |
| `i(` / `a(` | Inside / around parentheses |
| `i[` / `a[` | Inside / around brackets |
| `i{` / `a{` | Inside / around braces |
| `it` / `at` | Inside / around a tag |
| `ip` / `ap` | Paragraph / paragraph and blank line |

## Copy and paste

| Key | Action |
| --- | --- |
| `y` / `yy` / `p` | Copy selection / copy line / paste |
| `"_d` | Delete without replacing the clipboard |
| `"ay` / `"ap` | Copy to / paste from register `a` |

Copy and paste use the system clipboard.

## Search and replace

| Key | Action |
| --- | --- |
| `/text` / `?text` | Search forward / backward |
| `n` / `N` | Next / previous match |
| `*` / `#` | Search word under cursor |
| `Esc` | Clear highlight |
| `:%s/old/new/gc` | Replace in file, confirm each |
| `:'<,'>s/old/new/g` | Replace in selected lines |
| `:cfdo %s/old/new/gc` | Replace in every Quickfix file |
| `:cfdo update` | Save every Quickfix file |

Lowercase searches ignore case. `\V` makes a pattern literal, `\v` enables regex.

## Start screen

| Key | Action |
| --- | --- |
| `f` | Find file |
| `r` | Recent files |
| `/` | Search text |
| `?` | Notes |
| `e` / `i` | Empty buffer / empty buffer in Insert mode |
| `Tab` | Switch scene: black hole / quasar |
| `p` | Pause animation |
| `q` | Quit |

`:Interstellar [blackhole|quasar]` opens the start screen. Each launch picks a scene at random.

## Commands

| Command | Action |
| --- | --- |
| `:Notes [tmux]` | Open these notes |
| `:FzfLua keymaps` | Every live Neovim mapping, including plugin ones |
| `:FormatToggle` | Format on save on / off |
| `:ConformInfo` | Formatter status |
| `:checkhealth vim.lsp` | Language server status |
| `:Lazy` | Plugins |
| `:TSInstall <language>` | Install a syntax parser |
