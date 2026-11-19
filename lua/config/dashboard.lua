-- Start screen: an animated black hole or quasar (Tab switches). Each row is a single overlay extmark whose
-- virtual text carries the coloured half-blocks, so a frame is ~1 API call per row,
-- and only rows that changed are redrawn. The timer runs only while the screen is
-- visible and Neovim has focus.
local M = {}
local api, uv = vim.api, vim.uv
local scene = require("config.interstellar")
local ns = api.nvim_create_namespace("Interstellar")
local FPS = 15
local MAX_W, MAX_H = 260, 80
local HINTS = {
   { "f", "find file" },
   { "r", "recent" },
   { "/", "search" },
   { "?", "keys" },
   { "Tab", "scene" },
   { "q", "quit" },
}
local state

-- One quiet line of key hints near the bottom, drawn into the artwork.
local hint_cells
local function hints(w, h)
   if h < 20 or w < 70 then
      return nil
   end
   if not hint_cells then
      local p = require("theme.palette")
      local key, label = scene.key(p.active), scene.key(p.muted)
      hint_cells = {}
      for n, item in ipairs(HINTS) do
         for _, part in ipairs({ { item[1], key }, { " " .. item[2], label } }) do
            for char in part[1]:gmatch(".") do
               hint_cells[#hint_cells + 1] = { char, part[2] }
            end
         end
         for _ = 1, n < #HINTS and 5 or 0 do
            hint_cells[#hint_cells + 1] = { " ", label }
         end
      end
   end
   return { row = h - 2, col = math.floor((w - #hint_cells) / 2), cells = hint_cells }
end

local function render()
   if not state or not api.nvim_buf_is_valid(state.buf) then
      return
   end
   local win = vim.fn.bufwinid(state.buf)
   if win == -1 then
      return
   end
   local width, height = api.nvim_win_get_width(win), api.nvim_win_get_height(win)
   local w, h = math.min(MAX_W, width), math.min(MAX_H, height)
   local left, top = math.floor((width - w) / 2), math.floor((height - h) / 2)
   local rows, signatures = scene.frame(w, h, state.time, state.scene, hints(w, h))

   if state.width ~= width or state.height ~= height then
      state.width, state.height, state.marks, state.signatures = width, height, {}, {}
      vim.bo[state.buf].modifiable = true
      local blank = {}
      for i = 1, height do
         blank[i] = string.rep(" ", width)
      end
      api.nvim_buf_set_lines(state.buf, 0, -1, false, blank)
      vim.bo[state.buf].modifiable = false
      vim.bo[state.buf].modified = false
      api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
   end
   for row = 1, h do
      if state.signatures[row] ~= signatures[row] then
         state.signatures[row] = signatures[row]
         state.marks[row] = api.nvim_buf_set_extmark(state.buf, ns, top + row - 1, left, {
            id = state.marks[row],
            virt_text = rows[row],
            virt_text_pos = "overlay",
            priority = 100,
         })
      end
   end
end

local function stop()
   if state then
      state.timer:stop()
   end
end

local function start()
   stop()
   if not state or state.paused or not state.focused or api.nvim_get_current_buf() ~= state.buf then
      return
   end
   local last = uv.hrtime()
   state.timer:start(
      0,
      math.floor(1000 / FPS),
      vim.schedule_wrap(function()
         if not state or api.nvim_get_current_buf() ~= state.buf then
            return stop()
         end
         local now = uv.hrtime()
         state.time = state.time + math.min(0.2, (now - last) / 1e9)
         last = now
         render()
      end)
   )
end

local function pick(name)
   if vim.tbl_contains(scene.names, name) then
      return name
   end
   return scene.names[vim.uv.hrtime() % #scene.names + 1] -- a different one each launch
end

function M.open(name)
   if state and api.nvim_buf_is_valid(state.buf) then
      state.scene = name and pick(name) or state.scene
      api.nvim_win_set_buf(0, state.buf)
      return render()
   end
   if vim.bo.modified then
      return vim.notify("Save your changes first", vim.log.levels.WARN)
   end
   local buf = api.nvim_create_buf(false, true)
   local win = api.nvim_get_current_win()
   vim.bo[buf].bufhidden = "wipe"
   vim.bo[buf].filetype = "interstellar"
   api.nvim_win_set_buf(win, buf)
   for option, value in pairs({
      number = false,
      relativenumber = false,
      cursorline = false,
      signcolumn = "no",
      foldcolumn = "0",
      list = false,
      wrap = false,
      winbar = "",
      statuscolumn = "",
   }) do
      vim.wo[win][0][option] = value
   end
   state = {
      buf = buf,
      timer = assert(uv.new_timer()),
      time = 8,
      focused = true,
      paused = false,
      scene = pick(name),
   }
   render()

   local group = api.nvim_create_augroup("Interstellar", { clear = true })
   local au = function(events, fn, opts)
      api.nvim_create_autocmd(
         events,
         vim.tbl_extend("force", { group = group, callback = fn }, opts or {})
      )
   end
   au("BufLeave", stop, { buffer = buf })
   au("BufEnter", start, { buffer = buf })
   au({ "VimResized", "WinResized" }, render)
   au("ColorScheme", function()
      scene.reset_highlights()
      state.signatures = {}
      render()
   end)
   au("FocusLost", function()
      state.focused = false
      stop()
   end)
   au("FocusGained", function()
      state.focused = true
      start()
   end)
   au("BufWipeout", function()
      stop()
      state.timer:close()
      state = nil
      api.nvim_del_augroup_by_id(group)
   end, { buffer = buf, once = true })

   local function map(key, rhs, desc)
      vim.keymap.set("n", key, rhs, { buffer = buf, nowait = true, silent = true, desc = desc })
   end
   map("p", function()
      state.paused = not state.paused
      start()
   end, "Pause animation")
   map("<Tab>", function()
      local index = vim.fn.index(scene.names, state.scene)
      state.scene = scene.names[index % #scene.names + 1]
      render()
   end, "Switch scene (black hole / quasar)")
   map("f", function()
      require("fzf-lua").files()
   end, "Find file")
   map("r", function()
      require("fzf-lua").oldfiles()
   end, "Recent files")
   map("/", function()
      require("fzf-lua").live_grep()
   end, "Search text")
   map("?", function()
      require("config.notes").open("nvim")
   end, "Notes")
   map("e", "<Cmd>enew<CR>", "Empty buffer")
   map("i", "<Cmd>enew<CR>i", "Empty buffer, insert")
   map("q", "<Cmd>quit<CR>", "Quit")
   start()
end

function M.setup()
   api.nvim_create_user_command("Interstellar", function(opts)
      M.open(opts.args ~= "" and opts.args or nil)
   end, {
      nargs = "?",
      complete = function()
         return scene.names
      end,
      desc = "Open the start screen: blackhole or quasar",
   })
   local group = api.nvim_create_augroup("InterstellarStartup", { clear = true })
   local stdin = false
   api.nvim_create_autocmd("StdinReadPre", {
      group = group,
      callback = function()
         stdin = true
      end,
   })
   api.nvim_create_autocmd("VimEnter", {
      group = group,
      once = true,
      callback = function()
         if vim.env.NVIM_NOTES then -- `NVIM_NOTES=tmux nvim`: notes only (tmux Prefix ? popup)
            vim.o.laststatus, vim.o.ruler, vim.o.showcmd = 0, false, false
            return require("config.notes").open(vim.env.NVIM_NOTES == "nvim" and "nvim" or "tmux")
         end
         if
            not stdin
            and vim.fn.argc() == 0
            and api.nvim_buf_get_name(0) == ""
            and api.nvim_buf_line_count(0) == 1
            and api.nvim_buf_get_lines(0, 0, 1, false)[1] == ""
            and #api.nvim_list_uis() > 0
         then
            M.open()
         end
      end,
   })
end

return M
