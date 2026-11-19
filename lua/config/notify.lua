-- vim.notify as small toasts stacked in the top-right corner. They fade out on
-- their own (errors stay longer) and errors are also kept in :messages.
local M = {}
local api = vim.api
local levels = vim.log.levels
local native = vim.notify
local toasts = {}
local STYLE = {
   [levels.ERROR] = { "✕", "NotifyError", 6000 },
   [levels.WARN] = { "▲", "NotifyWarn", 4500 },
   [levels.INFO] = { "●", "NotifyInfo", 3000 },
}

local function restack()
   local row = 1
   for _, t in ipairs(toasts) do
      if api.nvim_win_is_valid(t.win) then
         api.nvim_win_set_config(
            t.win,
            { relative = "editor", anchor = "NE", row = row, col = vim.o.columns - 1 }
         )
         row = row + t.height + 2
      end
   end
end

local function dismiss(toast)
   for i, t in ipairs(toasts) do
      if t == toast then
         table.remove(toasts, i)
         break
      end
   end
   pcall(api.nvim_win_close, toast.win, true)
   restack()
end

function M.notify(message, level, opts)
   level = level or levels.INFO
   if #api.nvim_list_uis() == 0 or level < levels.INFO then
      return native(message, level, opts)
   end
   if vim.in_fast_event() then
      return vim.schedule(function()
         M.notify(message, level, opts)
      end)
   end
   local style = STYLE[level] or STYLE[levels.INFO]
   if level == levels.ERROR then
      api.nvim_echo({ { tostring(message), "ErrorMsg" } }, true, {})
   end
   local width = math.min(64, math.floor(vim.o.columns * 0.4))
   local lines = {}
   for _, line in ipairs(vim.split(tostring(message), "\n", { trimempty = true })) do
      for start = 1, math.max(1, #line), width - 4 do
         lines[#lines + 1] = (start == 1 and #lines == 0 and (style[1] .. " ") or "  ")
            .. line:sub(start, start + width - 5)
      end
   end
   lines = vim.list_slice(lines, 1, 8)
   local longest = 0
   for _, line in ipairs(lines) do
      longest = math.max(longest, vim.fn.strdisplaywidth(line))
   end
   local buf = api.nvim_create_buf(false, true)
   api.nvim_buf_set_lines(buf, 0, -1, false, lines)
   api.nvim_buf_set_extmark(buf, api.nvim_create_namespace("Notify"), 0, 0, {
      end_col = #style[1],
      hl_group = style[2],
   })
   vim.bo[buf].bufhidden = "wipe"
   local toast = { height = #lines }
   toast.win = api.nvim_open_win(buf, false, {
      relative = "editor",
      anchor = "NE",
      row = 1,
      col = vim.o.columns - 1,
      width = math.max(longest + 1, 16),
      height = #lines,
      border = "rounded",
      style = "minimal",
      focusable = false,
      zindex = 200,
      noautocmd = true,
   })
   vim.wo[toast.win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder"
   table.insert(toasts, 1, toast)
   while #toasts > 4 do
      dismiss(toasts[#toasts])
   end
   restack()
   vim.defer_fn(function()
      dismiss(toast)
   end, style[3])
end

vim.notify = M.notify
return M
