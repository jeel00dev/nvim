-- Floating terminal: one persistent shell that slides over the editor.
--   Space t  (Normal) or Alt-t (any mode, also inside the terminal): show / hide
--   Esc Esc  inside the terminal: Normal mode (scroll, copy); i returns to the shell
-- Exiting the shell closes it; the next toggle starts a fresh one.
local M = {}
local api = vim.api
local buf, win

local function config()
   local width = math.max(40, math.floor(vim.o.columns * 0.82))
   local height = math.max(10, math.floor(vim.o.lines * 0.72))
   return {
      relative = "editor",
      width = math.min(width, vim.o.columns - 4),
      height = math.min(height, vim.o.lines - 4),
      row = math.floor((vim.o.lines - height) / 2) - 1,
      col = math.floor((vim.o.columns - width) / 2),
      border = "rounded",
      title = { { " Terminal ", "FloatTitle" } },
      title_pos = "left",
      footer = {
         { " Alt-t ", "FloatKey" },
         { " hide  ", "FloatFooter" },
         { " Esc Esc ", "FloatKey" },
         { " scroll  ", "FloatFooter" },
      },
      footer_pos = "right",
      style = "minimal",
   }
end

function M.hide()
   if win and api.nvim_win_is_valid(win) then
      api.nvim_win_hide(win)
   end
   win = nil
end

function M.toggle()
   if win and api.nvim_win_is_valid(win) then
      return M.hide()
   end
   local fresh = not (buf and api.nvim_buf_is_valid(buf))
   if fresh then
      buf = api.nvim_create_buf(false, true)
   end
   win = api.nvim_open_win(buf, true, config())
   vim.wo[win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder"
   if fresh then
      vim.fn.jobstart(vim.o.shell, {
         term = true,
         cwd = vim.fn.getcwd(),
         on_exit = function()
            vim.schedule(function()
               M.hide()
               if buf and api.nvim_buf_is_valid(buf) then
                  api.nvim_buf_delete(buf, { force = true })
               end
               buf = nil
            end)
         end,
      })
      vim.bo[buf].bufhidden = "hide"
      local opts = { buffer = buf, silent = true }
      vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", opts)
      vim.keymap.set("n", "q", M.hide, opts)
      api.nvim_create_autocmd("WinLeave", { buffer = buf, callback = M.hide })
   end
   vim.cmd.startinsert()
end

api.nvim_create_autocmd("VimResized", {
   group = api.nvim_create_augroup("FloatingTerminal", { clear = true }),
   callback = function()
      if win and api.nvim_win_is_valid(win) then
         api.nvim_win_set_config(win, config())
      end
   end,
})

return M
