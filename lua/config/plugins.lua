local path = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(path) then
   local output = vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "--branch=stable",
      "https://github.com/folke/lazy.nvim.git",
      path,
   })
   if vim.v.shell_error ~= 0 then
      error("Could not install lazy.nvim:\n" .. output)
   end
end
vim.opt.rtp:prepend(path)

local function largefile(_, buf)
   return vim.b[buf].largefile == true
end

-- Keep the indentation the editor uses (3 spaces) when a formatter runs.
local function indent_args(_, ctx)
   return { "--config", "indent-width=" .. ctx.shiftwidth }
end
local function clang_args(_, ctx)
   local bo = vim.bo[ctx.buf]
   return {
      "--style=" .. vim.json.encode({
         BasedOnStyle = "InheritParentConfig",
         IndentWidth = ctx.shiftwidth,
         TabWidth = bo.tabstop,
         UseTab = bo.expandtab and "Never" or "Always",
      }),
   }
end

require("lazy").setup({
   {
      "nvim-treesitter/nvim-treesitter",
      branch = "master",
      lazy = false,
      build = ":TSUpdate",
      config = function()
         require("nvim-treesitter.configs").setup({
            ensure_installed = {},
            auto_install = false,
            highlight = { enable = true, disable = largefile },
         })
         if vim.fn.has("nvim-0.12") == 0 then
            return
         end
         -- The frozen master branch predates 0.12, where a capture holds a list of nodes.
         -- Re-register the two directives its installed queries use (Markdown, Bash).
         local function text(match, id, buf, metadata)
            local node = match[id]
            node = type(node) == "table" and node[#node] or node
            return node and vim.treesitter.get_node_text(node, buf, { metadata = metadata[id] })
         end
         vim.treesitter.query.add_directive(
            "set-lang-from-info-string!",
            function(match, _, buf, pred, metadata)
               local alias = text(match, pred[2], buf, metadata)
               if alias then
                  alias = alias:lower()
                  metadata["injection.language"] = vim.filetype.match({ filename = "a." .. alias })
                     or alias
               end
            end,
            { force = true }
         )
         vim.treesitter.query.add_directive("downcase!", function(match, _, buf, pred, metadata)
            local value = text(match, pred[2], buf, metadata)
            if value then
               metadata[pred[2]] = metadata[pred[2]] or {}
               metadata[pred[2]].text = value:lower()
            end
         end, { force = true })
      end,
   },
   {
      "ibhagwan/fzf-lua",
      cmd = "FzfLua",
      config = function()
         local fzf = require("fzf-lua")
         local p = require("theme.palette")
         fzf.setup({
            defaults = {
               file_icons = false,
               git_icons = false,
               prompt = "› ",
               formatter = "path.filename_first",
            },
            winopts = {
               height = 0.7,
               width = 0.8,
               row = 0.4,
               border = "rounded",
               backdrop = 55,
               title_pos = "left",
               title_flags = false,
               preview = {
                  border = "rounded",
                  layout = "flex",
                  flip_columns = 130,
                  horizontal = "right:52%",
                  scrollbar = "float",
                  title_pos = "left",
               },
            },
            fzf_opts = {
               ["--layout"] = "reverse",
               ["--info"] = "inline-right",
               ["--pointer"] = "▌",
               ["--marker"] = "▍",
               ["--separator"] = "─",
               ["--scrollbar"] = "▏",
               ["--ellipsis"] = "…",
            },
            fzf_colors = {
               ["fg"] = p.white,
               ["bg"] = p.float_bg,
               ["hl"] = p.active,
               ["fg+"] = p.bright,
               ["bg+"] = p.elevated,
               ["hl+"] = p.active,
               ["info"] = p.faint,
               ["prompt"] = p.active,
               ["pointer"] = p.active,
               ["marker"] = p.green,
               ["spinner"] = p.active,
               ["header"] = p.faint,
               ["border"] = p.border,
               ["gutter"] = p.float_bg,
               ["separator"] = p.separator,
               ["scrollbar"] = p.border,
               ["query"] = p.bright,
            },
            files = { cmd = "rg --files --hidden --glob '!.git'", cwd_prompt = false },
            grep = {
               rg_opts = "--column --line-number --no-heading --color=never --smart-case --hidden --glob '!.git' -e",
            },
            lsp = { jump1 = true },
            keymap = { fzf = { true, ["ctrl-q"] = "select-all+accept" } },
         })
         fzf.register_ui_select()
      end,
      init = function()
         -- Route vim.ui.select (code actions, etc.) through fzf-lua on first use.
         local native = vim.ui.select
         local function stub(...)
            require("fzf-lua")
            return (vim.ui.select ~= stub and vim.ui.select or native)(...)
         end
         vim.ui.select = stub
      end,
   },
   {
      "nvim-tree/nvim-tree.lua",
      cmd = { "NvimTreeToggle", "NvimTreeFindFileToggle" },
      init = function()
         -- `nvim some/dir` opens the tree for that directory.
         vim.api.nvim_create_autocmd("BufEnter", {
            group = vim.api.nvim_create_augroup("PersonalDirectory", { clear = true }),
            callback = function(ev)
               if vim.fn.isdirectory(ev.file) == 1 then
                  require("nvim-tree.api").tree.open({ path = ev.file })
               end
            end,
         })
      end,
      opts = {
         hijack_cursor = true,
         update_focused_file = { enable = true },
         view = { width = 32, signcolumn = "no", cursorline = true },
         renderer = {
            group_empty = true,
            root_folder_label = function(path)
               return " " .. vim.fn.fnamemodify(path, ":t"):upper()
            end,
            highlight_opened_files = "name",
            indent_width = 2,
            indent_markers = {
               enable = true,
               icons = { corner = "│", edge = "│", item = "│", bottom = " ", none = " " },
            },
            icons = {
               git_placement = "after",
               padding = " ",
               show = {
                  file = false,
                  folder = false,
                  folder_arrow = true,
                  git = true,
                  modified = false,
               },
               glyphs = {
                  folder = { arrow_closed = "▸", arrow_open = "▾" },
                  git = {
                     unstaged = "~",
                     staged = "+",
                     unmerged = "!",
                     renamed = ">",
                     untracked = "?",
                     deleted = "-",
                     ignored = ".",
                  },
               },
            },
         },
         filters = { git_ignored = true, custom = { "^\\.git$" } },
         actions = { open_file = { window_picker = { enable = false } } },
      },
   },
   {
      "lewis6991/gitsigns.nvim",
      event = { "BufReadPre", "BufNewFile" },
      opts = {
         signs = {
            add = { text = "▎" },
            change = { text = "▎" },
            delete = { text = "▁" },
            topdelete = { text = "▔" },
            changedelete = { text = "▎" },
            untracked = { text = "┆" },
         },
         signs_staged_enable = false,
         preview_config = { border = "rounded" },
         on_attach = function(buf)
            return not vim.b[buf].largefile
         end,
      },
   },
   {
      "stevearc/conform.nvim",
      event = "BufWritePre",
      cmd = "ConformInfo",
      opts = {
         formatters_by_ft = {
            python = { "ruff_format" },
            c = { "clang_format" },
            cpp = { "clang_format" },
            cuda = { "clang_format" },
            lua = { "stylua" },
            sh = { "shfmt" },
            bash = { "shfmt" },
            json = { "jq" },
         },
         formatters = {
            ruff_format = { prepend_args = indent_args },
            clang_format = { prepend_args = clang_args },
         },
         default_format_opts = { lsp_format = "fallback", timeout_ms = 3000 },
         format_on_save = function(buf)
            if vim.g.autoformat == false or vim.b[buf].largefile or vim.bo[buf].buftype ~= "" then
               return
            end
            return {}
         end,
      },
   },
   {
      "windwp/nvim-autopairs",
      event = "InsertEnter",
      opts = { check_ts = false },
   },
   {
      "folke/which-key.nvim",
      event = "VeryLazy",
      opts = {
         delay = 400,
         preset = "helix",
         icons = {
            mappings = false,
            colors = false,
            separator = "  ",
            group = "+",
            keys = {
               Space = "Space ",
               CR = "Enter ",
               Esc = "Esc ",
               Tab = "Tab ",
               BS = "Bksp ",
               C = "Ctrl-",
               M = "Alt-",
               S = "Shift-",
               Up = "Up ",
               Down = "Down ",
               Left = "Left ",
               Right = "Right ",
            },
         },
         win = { border = "rounded", padding = { 1, 2 }, title_pos = "left" },
      },
   },
}, {
   defaults = { lazy = true },
   checker = { enabled = false },
   change_detection = { enabled = false },
   install = { colorscheme = { "personal" } },
   ui = { border = "rounded", backdrop = 55, icons = { loaded = "●", not_loaded = "○" } },
   performance = {
      rtp = {
         disabled_plugins = {
            "gzip",
            "tarPlugin",
            "tohtml",
            "tutor",
            "zipPlugin",
            "netrwPlugin",
            "rplugin",
         },
      },
   },
})
