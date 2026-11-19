-- Use the project's virtualenv (activated, or .venv / venv in the project root).
local function python(root)
   local candidates = {
      vim.env.VIRTUAL_ENV or "",
      vim.env.CONDA_PREFIX or "",
      root and (root .. "/.venv") or "",
      root and (root .. "/venv") or "",
   }
   for _, dir in ipairs(candidates) do
      if dir ~= "" and vim.fn.executable(dir .. "/bin/python") == 1 then
         return dir .. "/bin/python"
      end
   end
end

return {
   cmd = { "basedpyright-langserver", "--stdio" },
   filetypes = { "python" },
   root_markers = {
      "pyproject.toml",
      "pyrightconfig.json",
      "setup.py",
      "setup.cfg",
      "requirements.txt",
      ".git",
   },
   settings = {
      basedpyright = {
         disableOrganizeImports = true, -- ruff owns imports
         analysis = {
            typeCheckingMode = "standard",
            diagnosticMode = "openFilesOnly",
            autoImportCompletions = true,
         },
      },
   },
   before_init = function(_, config)
      local interpreter = python(config.root_dir)
      if interpreter then
         config.settings.python = { pythonPath = interpreter }
      end
   end,
}
