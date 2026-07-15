-- Minimal, isolated Neovim config used only to record the demo GIF with VHS.
-- Loads just prompt-reference from the repo root — no personal config, no other
-- plugins — so the demo shows exactly what a new user gets.
local repo = vim.fn.fnamemodify(vim.fn.expand("<sfile>:p:h"), ":h")
vim.opt.runtimepath:prepend(repo)

vim.o.number = true
vim.o.termguicolors = true
vim.o.laststatus = 0
vim.o.cmdheight = 1
-- No colorscheme: use Neovim's built-in default so the demo matches a stock
-- setup (floating-window colors come from the default NormalFloat/FloatBorder).

require("prompt-reference").setup({
    output_style = "xml",
    keymaps = true, -- visual <CR> = add, <Tab><Tab> = review
})
