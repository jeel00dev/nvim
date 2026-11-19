vim.diagnostic.config({
   -- Inline message only on the cursor's line; elsewhere just the gutter mark.
   virtual_text = { current_line = true, prefix = "", spacing = 4 },
   signs = { text = { "✕", "▲", "●", "◆" } },
   underline = true,
   severity_sort = true,
   float = { border = "rounded", source = "if_many", header = "", prefix = "" },
   jump = { float = true },
})

vim.api.nvim_create_autocmd("LspAttach", {
   group = vim.api.nvim_create_augroup("PersonalLsp", { clear = true }),
   callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not client then
         return
      end
      if client:supports_method("textDocument/completion") then
         -- Suggest while typing identifiers, not only after trigger characters like "." or "->".
         local provider = client.server_capabilities.completionProvider
         local triggers = provider.triggerCharacters or {}
         for char in ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"):gmatch(".") do
            if not vim.list_contains(triggers, char) then
               triggers[#triggers + 1] = char
            end
         end
         provider.triggerCharacters = triggers
         vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
      end
   end,
})

-- Servers live in lsp/<name>.lua; each one starts only if its binary is installed.
-- Servers never attach to large files.
for _, server in ipairs({ "basedpyright", "ruff", "clangd" }) do
   local markers = vim.lsp.config[server].root_markers
   vim.lsp.config(server, {
      root_dir = function(buf, on_dir)
         if not vim.b[buf].largefile then
            on_dir(vim.fs.root(buf, markers) or vim.fs.dirname(vim.api.nvim_buf_get_name(buf)))
         end
      end,
   })
   if vim.fn.executable(vim.lsp.config[server].cmd[1]) == 1 then
      vim.lsp.enable(server)
   end
end
