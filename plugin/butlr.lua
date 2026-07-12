if vim.g.loaded_butlr then
  return
end
vim.g.loaded_butlr = true

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if require("butlr.detect").is_gitbutler() then
      require("butlr").enable()
    end
  end,
})

vim.api.nvim_create_autocmd("DirChanged", {
  callback = function()
    local butlr = require("butlr")
    if require("butlr.detect").is_gitbutler(true) then
      butlr.enable()
    else
      butlr.disable()
    end
  end,
})
