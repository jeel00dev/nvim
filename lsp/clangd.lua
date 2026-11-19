return {
   cmd = {
      "clangd",
      "--background-index",
      "--clang-tidy",
      "--completion-style=detailed",
      "--function-arg-placeholders=1",
      "--header-insertion=iwyu",
      "--header-insertion-decorators=0",
      "-j=2",
   },
   filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
   root_markers = { "compile_commands.json", "compile_flags.txt", ".clangd", ".git" },
}
