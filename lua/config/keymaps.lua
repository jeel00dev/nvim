-- Every global keymap lives in this file. docs/nvim.md lists them for reading (Space ?).
--
-- Rule: tmux is `Ctrl-b <key>`, Neovim is `Space <key>`, and the same key means the same
-- thing in both. Neovim never binds Ctrl-b or Alt-h/j/k/l, which tmux owns.

local function map(mode, lhs, rhs, desc)
   vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
end
local function fzf(picker, opts)
   return function()
      require("fzf-lua")[picker](opts)
   end
end

-- Splits: same letters as tmux panes ------------------------------------------------
map("n", "<leader>h", "<C-w>h", "Focus split left")
map("n", "<leader>j", "<C-w>j", "Focus split below")
map("n", "<leader>k", "<C-w>k", "Focus split above")
map("n", "<leader>l", "<C-w>l", "Focus split right")
map("n", "<leader>V", "<Cmd>vsplit<CR>", "Split side by side")
map("n", "<leader>H", "<Cmd>split<CR>", "Split top and bottom")
map("n", "<leader>x", "<Cmd>close<CR>", "Close split")
map("n", "<leader>z", function()
   if vim.t.zoom then
      vim.cmd(vim.t.zoom)
      vim.t.zoom = nil
   else
      vim.t.zoom = vim.fn.winrestcmd()
      vim.cmd.wincmd("|")
      vim.cmd.wincmd("_")
   end
end, "Zoom split (toggle)")
-- tmux resizes with Alt-h/j/k/l, Neovim with Alt-arrows.
map("n", "<M-Left>", "<Cmd>vertical resize -2<CR>", "Narrower split")
map("n", "<M-Right>", "<Cmd>vertical resize +2<CR>", "Wider split")
map("n", "<M-Up>", "<Cmd>resize +1<CR>", "Taller split")
map("n", "<M-Down>", "<Cmd>resize -1<CR>", "Shorter split")

-- Buffers: same letters as tmux windows ---------------------------------------------
map("n", "<leader>c", "<Cmd>enew<CR>", "New buffer")
map("n", "<leader>n", "<Cmd>bnext<CR>", "Next buffer")
map("n", "<leader>p", "<Cmd>bprevious<CR>", "Previous buffer")
map("n", "<leader>w", fzf("buffers"), "Choose buffer")
map("n", "<leader>&", "<Cmd>confirm bdelete<CR>", "Close buffer")

-- Terminal: `t` in both (Prefix t is a popup shell in tmux) ---------------------------
map("n", "<leader>t", function()
   require("config.terminal").toggle()
end, "Floating terminal")
map({ "n", "i", "x", "t" }, "<M-t>", function()
   require("config.terminal").toggle()
end, "Floating terminal (from any mode)")

-- Help: `?` in both tmux and Neovim -------------------------------------------------
map("n", "<leader>?", function()
   require("config.notes").open("nvim")
end, "Notes and keys (Tab: tmux)")
map("n", "<leader>K", function()
   require("config.notes").search()
end, "Search all keys (Neovim + tmux)")
vim.api.nvim_create_user_command("Notes", function(opts)
   require("config.notes").open(opts.args == "tmux" and "tmux" or "nvim")
end, {
   nargs = "?",
   complete = function()
      return { "nvim", "tmux" }
   end,
   desc = "Open Neovim or tmux notes",
})

-- Find -------------------------------------------------------------------------------
map("n", "<leader>f", fzf("files"), "Find file")
map("n", "<leader>r", fzf("oldfiles"), "Recent files")
map("n", "<leader>/", fzf("live_grep"), "Search text in project")
map("n", "<leader>*", fzf("grep_cword"), "Search word under cursor")
map("n", "<leader>s", fzf("lsp_document_symbols"), "Symbols in file")
map("n", "<leader>d", fzf("diagnostics_workspace"), "Diagnostics in project")
map("n", "<leader>e", "<Cmd>NvimTreeFindFileToggle<CR>", "File tree")
map("n", "<leader>q", function()
   vim.cmd(vim.fn.getqflist({ winid = 0 }).winid ~= 0 and "cclose" or "botright copen")
end, "Quickfix list (toggle)")

-- Code -------------------------------------------------------------------------------
-- Built in and kept: K hover, grn rename, gra code action, [d ]d diagnostics,
-- Ctrl-w d diagnostic float, Ctrl-s signature help (Insert), ]q [q quickfix, ]b [b buffers.
map("n", "gd", fzf("lsp_definitions"), "Go to definition")
map("n", "grr", fzf("lsp_references"), "References")
map("n", "gri", fzf("lsp_implementations"), "Implementations")
map("n", "grt", fzf("lsp_typedefs"), "Type definition")
map({ "n", "x" }, "<leader>=", function()
   require("conform").format({ async = true })
end, "Format file or selection")
vim.api.nvim_create_user_command("FormatToggle", function()
   vim.g.autoformat = vim.g.autoformat == false
   vim.notify("Format on save " .. (vim.g.autoformat and "on" or "off"))
end, { desc = "Toggle format on save" })

-- Git --------------------------------------------------------------------------------
map("n", "<leader>g", "<Cmd>Gitsigns preview_hunk<CR>", "Preview git change")
map("n", "<leader>b", "<Cmd>Gitsigns blame_line<CR>", "Blame line")
map("n", "]c", function()
   if vim.wo.diff then
      vim.cmd.normal({ "]c", bang = true })
   else
      require("gitsigns").nav_hunk("next")
   end
end, "Next git change")
map("n", "[c", function()
   if vim.wo.diff then
      vim.cmd.normal({ "[c", bang = true })
   else
      require("gitsigns").nav_hunk("prev")
   end
end, "Previous git change")

-- Completion (Insert) ----------------------------------------------------------------
vim.keymap.set("i", "<C-Space>", function()
   if #vim.lsp.get_clients({ bufnr = 0, method = "textDocument/completion" }) > 0 then
      return "<Cmd>lua vim.lsp.completion.get()<CR>"
   end
   return "<C-n>"
end, { expr = true, desc = "Show completion" })
for key, step in pairs({ ["<Tab>"] = 1, ["<S-Tab>"] = -1 }) do
   vim.keymap.set({ "i", "s" }, key, function()
      if vim.fn.pumvisible() == 1 then
         return step == 1 and "<C-n>" or "<C-p>"
      elseif vim.snippet.active({ direction = step }) then
         return ("<Cmd>lua vim.snippet.jump(%d)<CR>"):format(step)
      end
      return key
   end, { expr = true, desc = step == 1 and "Next completion" or "Previous completion" })
end

-- Editing ----------------------------------------------------------------------------
map("n", "<Esc>", "<Cmd>nohlsearch<CR>", "Clear search highlight")
map("x", "<", "<gv", "Unindent and keep selection")
map("x", ">", ">gv", "Indent and keep selection")
map("n", "j", "jzz", "Down a line (centered)")
map("n", "k", "kzz", "Up a line (centered)")
map("n", "<C-d>", "<C-d>zz", "Half page down (centered)")
map("n", "<C-u>", "<C-u>zz", "Half page up (centered)")
