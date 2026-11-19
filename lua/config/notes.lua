-- Notes viewer for docs/nvim.md and docs/tmux.md, rendered as a clean page:
-- headings with a hairline rule, tables as aligned columns, keys as highlighted
-- labels. Tab switches page, s searches every key in both, q closes.
-- `NVIM_NOTES=tmux nvim` opens it full screen (used by the tmux Prefix ? popup).
local M = {}
local api = vim.api
local ns = api.nvim_create_namespace("Notes")
local win
local PAGES = { nvim = "Neovim", tmux = "tmux" }

local function path(page)
   return vim.fn.stdpath("config") .. "/docs/" .. page .. ".md"
end

-- Split `code` spans out of a string: returns plain text and key ranges.
local function inline(text)
   local out, marks, pos = "", {}, 1
   text = text:gsub("%[([^%]]+)%]%([^%)]+%)", "%1"):gsub("%*%*(.-)%*%*", "%1")
   while true do
      local s, e, code = text:find("`([^`]+)`", pos)
      if not s then
         return out .. text:sub(pos), marks
      end
      out = out .. text:sub(pos, s - 1)
      marks[#marks + 1] = { #out, #out + #code }
      out = out .. code
      pos = e + 1
   end
end

local function cells(line)
   local body = vim.trim(line):gsub("^|", ""):gsub("|$", "")
   return vim.tbl_map(vim.trim, vim.split(body, "|", { plain = true }))
end

local function wrap(text, width)
   local lines, line = {}, ""
   for word in text:gmatch("%S+") do
      if line ~= "" and vim.fn.strdisplaywidth(line .. " " .. word) > width then
         lines[#lines + 1] = line
         line = word
      else
         line = line == "" and word or (line .. " " .. word)
      end
   end
   lines[#lines + 1] = line
   return lines
end

-- Markdown lines -> { lines, marks = { {row, col, end_col, group} }, rows = source -> row }
local function render(source, width)
   local out, marks, rows = {}, {}, {}
   local pad = "  "
   local function emit(text, group, keys, source_line)
      out[#out + 1] = text
      local row = #out - 1
      if group then
         marks[#marks + 1] = { row, 0, #text, group }
      end
      for _, k in ipairs(keys or {}) do
         marks[#marks + 1] = { row, k[1], k[2], "FloatKey" }
      end
      if source_line then
         rows[source_line] = rows[source_line] or #out
      end
   end
   local function blank()
      if #out > 0 and out[#out] ~= "" then
         emit("")
      end
   end

   local i, fence = 1, false
   while i <= #source do
      local line = source[i]
      if line:match("^```") then
         fence = not fence
         blank()
      elseif fence then
         emit(pad .. pad .. line, "NotesCode", nil, i)
      elseif line:match("^# ") then -- the page name is already in the window title
      elseif line:match("^## ") then
         blank()
         emit("")
         local title = line:sub(4):upper()
         local rule =
            string.rep("─", math.max(0, width - #pad * 2 - vim.fn.strdisplaywidth(title) - 2))
         emit(pad .. title .. "  " .. rule, nil, nil, i)
         marks[#marks + 1] = { #out - 1, 0, #pad + #title, "NotesHeading" }
         marks[#marks + 1] = { #out - 1, #pad + #title, #out[#out], "NotesRule" }
         emit("")
      elseif line:match("^|") then
         -- Collect the whole table, then lay it out in aligned columns.
         local tbl = {}
         while i <= #source and source[i]:match("^|") do
            if not source[i]:match("^| *%-%-%-") then
               tbl[#tbl + 1] = { cells(source[i]), i }
            end
            i = i + 1
         end
         i = i - 1
         local header = table.remove(tbl, 1)
         local show_header = header and #header[1] > 2
         local widths = {}
         for _, row in ipairs(show_header and { header, unpack(tbl) } or tbl) do
            for c = 1, #row[1] - 1 do
               widths[c] = math.max(widths[c] or 0, vim.fn.strdisplaywidth((inline(row[1][c]))))
            end
         end
         local function layout(row, is_header)
            local text, keys = pad, {}
            for c = 1, #row[1] - 1 do
               local plain, ranges = inline(row[1][c])
               for _, r in ipairs(ranges) do
                  keys[#keys + 1] = { #text + r[1], #text + r[2] }
               end
               text = text
                  .. plain
                  .. string.rep(" ", widths[c] - vim.fn.strdisplaywidth(plain) + 3)
            end
            local indent = vim.fn.strdisplaywidth(text)
            local desc, ranges = inline(row[1][#row[1]])
            local wrapped = wrap(desc, math.max(20, width - indent - 2))
            local offset = #text
            for _, r in ipairs(ranges) do
               if r[2] <= #wrapped[1] then
                  keys[#keys + 1] = { offset + r[1], offset + r[2] }
               end
            end
            emit(
               text .. wrapped[1],
               is_header and "NotesMuted" or nil,
               not is_header and keys or nil,
               row[2]
            )
            for w = 2, #wrapped do
               emit(string.rep(" ", indent) .. wrapped[w], "NotesMuted")
            end
         end
         if show_header then
            layout(header, true)
         end
         for _, row in ipairs(tbl) do
            layout(row, false)
         end
      elseif line:match("^%s*$") then
         blank()
      else
         -- Paragraph: join following lines, wrap, keep key labels.
         local first, text = i, line
         while source[i + 1] and source[i + 1]:match("%S") and not source[i + 1]:match("^[#|`]") do
            i = i + 1
            text = text .. " " .. source[i]
         end
         local plain, ranges = inline(text)
         local consumed = 0
         for n, piece in ipairs(wrap(plain, width - #pad * 2)) do
            local keys = {}
            local from = plain:find(piece, consumed + 1, true) or consumed + 1
            for _, r in ipairs(ranges) do
               if r[1] >= from - 1 and r[2] <= from - 1 + #piece then
                  keys[#keys + 1] = { #pad + r[1] - (from - 1), #pad + r[2] - (from - 1) }
               end
            end
            consumed = from + #piece - 1
            emit(pad .. piece, "NotesMuted", keys, n == 1 and first or nil)
         end
      end
      i = i + 1
   end
   return out, marks, rows
end

local function title(page)
   local chunks = { { " ", "FloatBorder" } }
   for _, name in ipairs({ "nvim", "tmux" }) do
      chunks[#chunks + 1] =
         { " " .. PAGES[name] .. " ", name == page and "FloatKey" or "FloatFooter" }
      chunks[#chunks + 1] = { " ", "FloatBorder" }
   end
   return chunks
end

local function footer()
   local chunks = {}
   for _, item in ipairs({
      { "Tab", "switch" },
      { "s", "search keys" },
      { "/", "find" },
      { "q", "close" },
   }) do
      chunks[#chunks + 1] = { " " .. item[1] .. " ", "FloatKey" }
      chunks[#chunks + 1] = { " " .. item[2] .. "  ", "FloatFooter" }
   end
   return chunks
end

function M.open(page, source_line)
   local standalone = vim.env.NVIM_NOTES ~= nil
   local width = standalone and vim.o.columns - 2 or math.min(96, vim.o.columns - 6)
   local height = standalone and vim.o.lines - 3 or math.min(42, vim.o.lines - 5)
   local lines, marks, rows = render(vim.fn.readfile(path(page)), width - 2)

   local buf = api.nvim_create_buf(false, true)
   api.nvim_buf_set_lines(buf, 0, -1, false, lines)
   for _, m in ipairs(marks) do
      pcall(
         api.nvim_buf_set_extmark,
         buf,
         ns,
         m[1],
         m[2],
         { end_col = m[3], hl_group = m[4], priority = m[4] == "FloatKey" and 200 or 100 }
      )
   end
   vim.bo[buf].modifiable = false
   vim.bo[buf].bufhidden = "wipe"
   vim.bo[buf].filetype = "notes"

   local config = {
      relative = "editor",
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2) - 1,
      col = math.floor((vim.o.columns - width) / 2),
      border = "rounded",
      title = title(page),
      title_pos = "left",
      footer = footer(),
      footer_pos = "right",
   }
   if win and api.nvim_win_is_valid(win) then
      api.nvim_win_set_buf(win, buf)
      api.nvim_win_set_config(win, config)
   else
      config.style = "minimal"
      win = api.nvim_open_win(buf, true, config)
   end
   vim.wo[win].winhighlight = "Normal:NotesText,CursorLine:FloatCursorLine,FloatBorder:FloatBorder"
   vim.wo[win].cursorline = true
   vim.wo[win].wrap = false
   if source_line then
      local row = rows[source_line]
      for l = source_line, 1, -1 do
         row = row or rows[l]
      end
      api.nvim_win_set_cursor(win, { row or 1, 0 })
      vim.cmd("normal! zz")
   end

   local function close()
      if standalone then
         vim.cmd("qa!")
      elseif api.nvim_win_is_valid(win) then
         api.nvim_win_close(win, true)
      end
   end
   local function map(key, fn)
      vim.keymap.set("n", key, fn, { buffer = buf, nowait = true, silent = true })
   end
   map("q", close)
   map("<Esc>", close)
   map("s", M.search)
   map("<Tab>", function()
      M.open(page == "nvim" and "tmux" or "nvim")
   end)
end

-- Every key in both notes: "nvim  Space f  Find file · Find". Enter opens the row.
function M.search()
   local rows = {}
   for _, page in ipairs({ "nvim", "tmux" }) do
      local section = ""
      for number, text in ipairs(vim.fn.readfile(path(page))) do
         section = text:match("^## (.+)") or section
         if text:match("^|") and not text:match("^| *%-%-%-") and not text:match("^| *Key *|") then
            local row = vim.tbl_map(function(cell)
               return (cell:gsub("`", ""))
            end, cells(text))
            if row[1] ~= "tmux" and row[1] ~= "Command" then
               local action = table.remove(row)
               rows[#rows + 1] = string.format(
                  "%s:%d\t%-5s  %-34s %s  · %s",
                  page,
                  number,
                  page,
                  table.concat(row, "  ·  "),
                  action,
                  section
               )
            end
         end
      end
   end
   require("fzf-lua").fzf_exec(rows, {
      prompt = "› ",
      winopts = { title = " Keys ", height = 0.6, width = 0.75 },
      fzf_opts = { ["--delimiter"] = "\t", ["--with-nth"] = "2" },
      actions = {
         default = function(selected)
            local page, line = (selected[1] or ""):match("^(%a+):(%d+)")
            if page then
               M.open(page, tonumber(line))
            end
         end,
      },
   })
end

return M
