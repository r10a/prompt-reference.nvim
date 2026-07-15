-- Commands are always available (no setup() required). Keymaps are opt-in via
-- require("prompt-reference").setup({ keymaps = true }).
if vim.g.loaded_prompt_reference then
    return
end
vim.g.loaded_prompt_reference = true

local function pr()
    return require("prompt-reference")
end

vim.api.nvim_create_user_command("PromptReferenceAdd", function()
    pr().add_selection()
end, { range = true, desc = "Add the selection (with a prompt) to the review" })

vim.api.nvim_create_user_command("PromptReferenceReview", function()
    pr().review()
end, { desc = "Open the prompt-reference review" })

vim.api.nvim_create_user_command("PromptReferenceCopy", function()
    pr().copy_all()
end, { desc = "Copy the review to the clipboard and clear it" })
