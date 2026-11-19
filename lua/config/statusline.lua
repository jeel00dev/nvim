--  NORMAL   lua/config/ keymaps.lua ●                 ✕ 2  ▲ 1    main   lua   Ln 12, Col 4
local modes = {
   n = { "NORMAL", "Normal" },
   no = { "PENDING", "Normal" },
   i = { "INSERT", "Insert" },
   ic = { "INSERT", "Insert" },
   v = { "VISUAL", "Visual" },
   V = { "V-LINE", "Visual" },
   ["\22"] = { "V-BLOCK", "Visual" },
   s = { "SELECT", "Visual" },
   S = { "S-LINE", "Visual" },
   R = { "REPLACE", "Replace" },
   c = { "COMMAND", "Command" },
   t = { "TERMINAL", "Terminal" },
   nt = { "NORMAL", "Normal" },
}

local function escape(text)
   return (text:gsub("%%", "%%%%"))
end

return function()
   local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
   local mode = modes[vim.api.nvim_get_mode().mode]
      or modes[vim.api.nvim_get_mode().mode:sub(1, 1)]
      or modes.n
   -- In a floating window (picker, terminal, notes), keep describing the file below it.
   if vim.api.nvim_win_get_config(win).relative ~= "" then
      local float_ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
      if float_ft == "fzf" then
         mode = { "SEARCH", "Command" }
      elseif float_ft == "notes" then
         mode = { "NOTES", "Normal" }
      end
      win = vim.fn.win_getid(vim.fn.winnr("#"))
      if win == 0 or vim.api.nvim_win_get_config(win).relative ~= "" then
         win = vim.tbl_filter(function(w)
            return vim.api.nvim_win_get_config(w).relative == ""
         end, vim.api.nvim_tabpage_list_wins(0))[1]
      end
   end
   local buf = vim.api.nvim_win_get_buf(win)
   local ft, bt = vim.bo[buf].filetype, vim.bo[buf].buftype
   if ft == "interstellar" then
      return ""
   end
   local width = vim.o.columns
   local left = "  %#StatusLineMode" .. mode[2] .. "#" .. mode[1] .. "   "

   -- Path: dim directory, bright file name.
   local name = vim.api.nvim_buf_get_name(buf)
   if bt == "terminal" then
      left = left .. "%#StatusLineFile#Terminal"
   elseif ft == "NvimTree" then
      left = left .. "%#StatusLineFile#Explorer"
   elseif name == "" then
      left = left .. "%#StatusLineFile#Untitled"
   else
      local path = vim.fn.fnamemodify(name, ":~:.")
      local dir, file = path:match("^(.*/)([^/]*)$")
      dir, file = dir or "", file or path
      if #dir > width / 3 then
         dir = "…" .. dir:sub(-math.floor(width / 3))
      end
      left = left .. "%#StatusLineDir#" .. escape(dir) .. "%#StatusLineFile#" .. escape(file)
   end
   if vim.bo[buf].modified then
      left = left .. "%#StatusLineAccent# ●"
   elseif vim.bo[buf].readonly or not vim.bo[buf].modifiable and bt == "" then
      left = left .. "%#StatusLineMuted# (read-only)"
   end

   -- Right side, dropping detail as the window narrows.
   local right = {}
   local counts = vim.diagnostic.count(buf)
   local problems = {}
   if (counts[1] or 0) > 0 then
      problems[#problems + 1] = "%#StatusLineError#✕ " .. counts[1]
   end
   if (counts[2] or 0) > 0 then
      problems[#problems + 1] = "%#StatusLineWarn#▲ " .. counts[2]
   end
   if #problems > 0 then
      right[#right + 1] = table.concat(problems, "  ")
   end
   local branch = vim.b[buf].gitsigns_head
   if width >= 90 and branch and branch ~= "" then
      right[#right + 1] = "%#StatusLineMuted#" .. escape(branch)
   end
   if width >= 70 and ft ~= "" and bt == "" then
      right[#right + 1] = "%#StatusLineMuted#" .. ft
   end
   if bt == "" then
      local cursor = vim.api.nvim_win_get_cursor(win)
      right[#right + 1] = "%#StatusLineMuted#Ln " .. cursor[1] .. ", Col " .. (cursor[2] + 1)
   end
   return left .. "%#StatusLine#%=" .. table.concat(right, "%#StatusLine#    ") .. "  "
end
