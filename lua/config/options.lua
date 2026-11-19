local o = vim.opt

-- Interface
o.termguicolors = true
o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.cursorline = true
o.wrap = false
o.scrolloff = 5
o.sidescrolloff = 6
o.splitright = true
o.splitbelow = true
o.splitkeep = "screen"
o.mouse = "a"
o.showmode = false
o.laststatus = 3
o.winborder = "rounded"
o.fillchars = { eob = " ", fold = " ", vert = "│", horiz = "─", diff = "╱" }
o.list = true
o.listchars = { tab = "› ", trail = "·", nbsp = "␣" }
o.foldmethod = "indent"
o.foldlevel = 99
o.shortmess:append("I")
o.statusline = "%!v:lua.require'config.statusline'()"

-- Search
o.ignorecase = true
o.smartcase = true
o.inccommand = "split"

-- Timing: short key timeout keeps Space-sequences snappy; tmux escape-time is set in tmux/nvim.conf.
o.updatetime = 300
o.timeoutlen = 500
o.ttimeoutlen = 10

-- Editing (3-space indent everywhere, including Python and Rust)
vim.g.python_recommended_style = 0
vim.g.rust_recommended_style = 0
o.expandtab = true
o.shiftwidth = 3
o.tabstop = 3
o.softtabstop = -1
o.smartindent = true
o.shiftround = true
o.undofile = true
o.confirm = true
o.clipboard = "unnamedplus"
o.completeopt = { "menu", "menuone", "noselect", "popup", "fuzzy" }
o.pumheight = 12
o.pumwidth = 20
if vim.fn.exists("+pumborder") == 1 then -- Neovim 0.12+
   o.pumborder = "rounded"
end

local group = vim.api.nvim_create_augroup("PersonalOptions", { clear = true })
local autocmd = vim.api.nvim_create_autocmd

-- Reopen files at the last cursor position.
autocmd("BufReadPost", {
   group = group,
   callback = function(ev)
      local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
      if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
         pcall(vim.api.nvim_win_set_cursor, 0, mark)
      end
   end,
})

autocmd("TextYankPost", {
   group = group,
   callback = function()
      vim.hl.on_yank({ timeout = 120 })
   end,
})

autocmd({ "FocusGained", "TermLeave" }, { group = group, command = "checktime" })
autocmd("ModeChanged", { group = group, command = "redrawstatus" })

autocmd("FileType", {
   group = group,
   pattern = { "help", "man", "qf", "checkhealth" },
   callback = function(ev)
      vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = ev.buf, desc = "Close" })
   end,
})

-- Files of 2 MiB or more open without syntax, LSP, undo history or swap.
autocmd("BufReadPre", {
   group = group,
   callback = function(ev)
      local stat = vim.uv.fs_stat(ev.match)
      if stat and stat.size >= 2 * 1024 * 1024 then
         vim.b[ev.buf].largefile = true
         vim.bo[ev.buf].swapfile = false
         vim.bo[ev.buf].undofile = false
      end
   end,
})
autocmd("FileType", {
   group = group,
   callback = function(ev)
      if vim.b[ev.buf].largefile then
         vim.schedule(function() -- after the built-in FileType handler sets 'syntax'
            if vim.api.nvim_buf_is_valid(ev.buf) then
               vim.bo[ev.buf].syntax = ""
            end
         end)
      end
   end,
})
