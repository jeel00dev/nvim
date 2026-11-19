if vim.fn.has("nvim-0.11") == 0 then
   error("This configuration needs Neovim 0.11 or newer.")
end

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
-- No remote plugins: skip provider detection (python3 alone costs ~90 ms per Python file).
for _, provider in ipairs({ "python3", "node", "perl", "ruby" }) do
   vim.g["loaded_" .. provider .. "_provider"] = 0
end

require("config.options")
require("config.notify")
vim.cmd.colorscheme("personal")
require("config.plugins")
require("config.lsp")
require("config.keymaps")
require("config.dashboard").setup()
