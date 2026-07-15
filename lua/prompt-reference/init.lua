-- prompt-reference.nvim
-- Stage `path:line` code references, each with its own prompt, into a review;
-- then copy the whole review (markdown or XML) to paste into an LLM.

local M = {}

M.config = {
    register = "+", -- register to copy into (default: system clipboard)
    use_git_root = true, -- path relative to git root; falls back to cwd-relative
    include_code = true, -- append the selected code (fenced block / xml body)
    output_style = "markdown", -- "markdown" or "xml" (xml is parsed more reliably by Claude)
    -- Set `keymaps = false` to bind nothing. Any entry can be set to false to
    -- skip just that mapping. Defaults are opt-in via setup({ keymaps = true }).
    keymaps = {
        add = "<CR>", -- (visual) add the selection to the review
        review = "<Tab><Tab>", -- (normal) open the review window
        copy = false, -- (normal) copy the review without opening it
    },
}

local SEP = " — " -- separates ref from prompt in the summary view

-- Resolve the current buffer's path for the reference.
local function ref_path()
    local abs = vim.fn.expand("%:p")
    if abs == "" then
        return "[No Name]"
    end
    abs = vim.fn.resolve(abs) -- resolve symlinks so it matches git's real path
    if M.config.use_git_root then
        local root = vim.fn.systemlist({
            "git", "-C", vim.fn.expand("%:p:h"), "rev-parse", "--show-toplevel",
        })[1]
        if vim.v.shell_error == 0 and root and root ~= "" and abs:sub(1, #root + 1) == root .. "/" then
            return abs:sub(#root + 2)
        end
    end
    return vim.fn.fnamemodify(abs, ":.") -- cwd-relative fallback
end

-- Format `ctx` as markdown: a `path:line` header, fenced code, optional prompt.
-- ctx = { path, range, code?, filetype, prompt? }
local function format_markdown(ctx)
    local parts = { ctx.path .. ":" .. ctx.range }
    if ctx.code then
        table.insert(parts, "```" .. ctx.filetype)
        table.insert(parts, ctx.code)
        table.insert(parts, "```")
    end
    if ctx.prompt and ctx.prompt ~= "" then
        table.insert(parts, "")
        table.insert(parts, ctx.prompt)
    end
    return table.concat(parts, "\n")
end

-- Format `ctx` as XML, which Claude parses with less ambiguity. Each item is
-- wrapped in <item> so the file and its prompt are unambiguously paired.
local function format_xml(ctx)
    local parts = {}
    local attrs = string.format('path="%s" lines="%s"', ctx.path, ctx.range)
    if ctx.filetype ~= "" then
        attrs = attrs .. string.format(' language="%s"', ctx.filetype)
    end
    if ctx.code then
        table.insert(parts, string.format("<file %s>\n%s\n</file>", attrs, ctx.code))
    else
        table.insert(parts, string.format("<file %s />", attrs))
    end
    if ctx.prompt and ctx.prompt ~= "" then
        table.insert(parts, "<prompt>\n" .. ctx.prompt .. "\n</prompt>")
    end
    return "<item>\n" .. table.concat(parts, "\n") .. "\n</item>"
end

local function format_ctx(ctx)
    local formatter = M.config.output_style == "xml" and format_xml or format_markdown
    return formatter(ctx)
end

-- Build a context table from a line range and its text. Reads path/filetype
-- from the *current* buffer, so call this before opening any prompt window.
local function capture(line1, line2, lines)
    if line1 > line2 then
        line1, line2 = line2, line1 -- normalize upward selections
    end
    return {
        path = ref_path(),
        range = line1 == line2 and tostring(line1) or (line1 .. "-" .. line2),
        filetype = vim.bo.filetype,
        code = M.config.include_code and table.concat(lines, "\n") or nil,
    }
end

-- Capture the current visual selection into a context table (charwise
-- selections keep only the highlighted text, not whole lines).
local function capture_selection()
    local mode = vim.fn.mode()
    local p1, p2 = vim.fn.getpos("v"), vim.fn.getpos(".")
    local lines = vim.fn.getregion(p1, p2, { type = mode })
    return capture(p1[2], p2[2], lines)
end

-- Staged items for the review (in-memory; cleared on copy_all).
local staged = {}

-- Render all staged items into one payload. XML items are each self-contained
-- (<item>...</item>), so they're simply concatenated with no outer wrapper.
local function format_batch(items)
    local blocks = {}
    for _, ctx in ipairs(items) do
        blocks[#blocks + 1] = format_ctx(ctx)
    end
    return table.concat(blocks, "\n\n")
end

-- First few words of a prompt, for the compact summary view.
local function prompt_snippet(prompt, word_count)
    local words = {}
    for w in prompt:gmatch("%S+") do
        words[#words + 1] = w
        if #words >= (word_count or 6) then
            break
        end
    end
    local snippet = table.concat(words, " ")
    -- add an ellipsis if we stopped short of the full prompt
    if #snippet < #vim.trim(prompt) then
        snippet = snippet .. "…"
    end
    return snippet
end

-- One summary line per staged item: "1. path:range — first few words".
local function summary_lines(items)
    local lines = {}
    for i, ctx in ipairs(items) do
        local note = (ctx.prompt and ctx.prompt ~= "") and (SEP .. prompt_snippet(ctx.prompt)) or ""
        lines[i] = string.format("%d. %s:%s%s", i, ctx.path, ctx.range, note)
    end
    return lines
end

-- Window config anchored to the bottom-right of the editor.
local function bottom_right(lines, opts)
    local width = 24
    for _, l in ipairs(lines) do
        width = math.max(width, vim.fn.strdisplaywidth(l))
    end
    width = math.min(width + 2, vim.o.columns - 2)
    local height = math.min(math.max(#lines, 1), opts.max_height or 10)
    return {
        relative = "editor",
        width = width,
        height = height,
        row = math.max(0, vim.o.lines - height - 3),
        col = math.max(0, vim.o.columns - width - 1),
        style = "minimal",
        border = "rounded",
        title = opts.title,
        title_pos = "center",
        focusable = opts.focusable,
        noautocmd = true,
    }
end

-- Window config for a small centered help popup sized to its lines.
local function centered_help(lines)
    local width = 20
    for _, l in ipairs(lines) do
        width = math.max(width, vim.fn.strdisplaywidth(l))
    end
    width = math.min(width + 2, vim.o.columns - 2)
    local height = #lines
    return {
        relative = "editor",
        width = width,
        height = height,
        row = math.max(0, math.floor((vim.o.lines - height) / 2)),
        col = math.max(0, math.floor((vim.o.columns - width) / 2)),
        style = "minimal",
        border = "rounded",
        title = " Keys ",
        title_pos = "center",
        noautocmd = true,
    }
end

-- The persistent, read-only review panel at the bottom-right. Shown only while
-- items are staged; rebuilt on every change.
M._panel = nil
local function refresh_panel()
    if M._panel and vim.api.nvim_win_is_valid(M._panel.win) then
        vim.api.nvim_win_close(M._panel.win, true)
    end
    M._panel = nil
    if #staged == 0 then
        return
    end
    local lines = summary_lines(staged)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    local win = vim.api.nvim_open_win(buf, false, bottom_right(lines, {
        title = string.format(" Review (%d) ", #staged),
        focusable = false,
        max_height = 10,
    }))
    M._panel = { win = win, buf = buf }
end

-- Open a floating window to enter a prompt; calls `on_submit(text)` on <CR>, or
-- does nothing on <Esc>/q (cancel). opts:
--   initial  string to pre-fill the input with (edited in place)
--   context  list of code lines shown read-only above the input, for reference
local function open_prompt(on_submit, opts)
    opts = opts or {}
    local ctx_lines = opts.context or {}

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    -- With context, use a large centered window; otherwise a slim cursor popup.
    local width = #ctx_lines > 0
        and math.max(40, math.min(120, math.floor(vim.o.columns * 0.8)))
        or math.min(80, math.max(20, vim.o.columns - 4))

    if #ctx_lines > 0 then
        -- Show the captured selection as read-only context, then a separator,
        -- then the (editable) prompt input on the final line. Cap generously so
        -- long selections still fit within the screen.
        local max_ctx = math.max(1, vim.o.lines - 8)
        local shown = {}
        for i = 1, math.min(#ctx_lines, max_ctx) do
            shown[i] = ctx_lines[i]
        end
        if #ctx_lines > max_ctx then
            shown[#shown + 1] = string.format("… (%d more lines)", #ctx_lines - max_ctx)
        end
        local buf_lines = vim.list_extend({}, shown)
        buf_lines[#buf_lines + 1] = string.rep("─", width)
        buf_lines[#buf_lines + 1] = opts.initial or ""
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, buf_lines)
    elseif opts.initial and opts.initial ~= "" then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { opts.initial })
    end

    -- Height must count wrapped display rows, not just buffer lines: a long
    -- paragraph on one line spans several screen rows.
    local display_rows = 0
    for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        display_rows = display_rows + math.max(1, math.ceil(vim.fn.strdisplaywidth(line) / width))
    end
    local input_row = math.max(0, vim.api.nvim_buf_line_count(buf) - 1)
    local height = math.max(1, math.min(display_rows, vim.o.lines - 4))
    local win_opts = {
        width = width,
        height = height,
        style = "minimal",
        border = "rounded",
        title = " Prompt (Enter to add, Esc to cancel) ",
        title_pos = "center",
    }
    if #ctx_lines > 0 then
        -- Center on the editor so the whole context is visible (the cursor may be
        -- in the bottom-right review panel, which would push it off-screen).
        win_opts.relative = "editor"
        win_opts.row = math.max(0, math.floor((vim.o.lines - height) / 2))
        win_opts.col = math.max(0, math.floor((vim.o.columns - width) / 2))
    else
        win_opts.relative = "cursor"
        win_opts.row = 1
        win_opts.col = 0
    end
    local win = vim.api.nvim_open_win(buf, true, win_opts)
    vim.wo[win].wrap = true -- wrap long context/paragraph lines

    -- Put the cursor on the prompt (last) line and enter insert at line end.
    vim.api.nvim_win_set_cursor(win, { input_row + 1, 0 })
    vim.cmd("startinsert")
    if opts.initial and opts.initial ~= "" then
        vim.cmd("normal! $")
        vim.cmd("startinsert!")
    end

    local function close()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
        vim.cmd("stopinsert")
    end
    local function submit()
        -- The prompt is only the input line(s) after the context/separator.
        local all = vim.api.nvim_buf_get_lines(buf, input_row, -1, false)
        local text = vim.trim(table.concat(all, "\n"))
        close()
        on_submit(text)
    end

    vim.keymap.set({ "i", "n" }, "<CR>", submit, { buffer = buf, nowait = true })
    vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true })
    vim.keymap.set("n", "q", close, { buffer = buf, nowait = true })
end

-- Stage the visual selection (with a per-item prompt) into the review.
function M.add_selection()
    local ctx = capture_selection() -- capture while still in the source buffer
    open_prompt(function(prompt)
        ctx.prompt = prompt
        staged[#staged + 1] = ctx
        refresh_panel()
        vim.notify(string.format("Staged %s:%s (%d in review)", ctx.path, ctx.range, #staged))
    end)
end

-- Copy the whole review to the register, then clear it.
function M.copy_all()
    if #staged == 0 then
        vim.notify("prompt-reference: nothing staged", vim.log.levels.WARN)
        return
    end
    vim.fn.setreg(M.config.register, format_batch(staged))
    vim.notify(string.format("Copied review of %d references", #staged))
    staged = {}
    refresh_panel()
end

-- Open a read-only Review view. `staged` is the single source of truth; edits
-- happen through item actions, not by typing into the buffer:
--   <CR> copy the whole review to the register and clear it
--   dd   delete the item under the cursor
--   r    re-enter the prompt for the item
--   ?    show the keybinding help
--   <Tab><Tab> / <Esc>  close the review
function M.review()
    if #staged == 0 then
        vim.notify("prompt-reference: nothing staged", vim.log.levels.WARN)
        return
    end
    if M._panel and vim.api.nvim_win_is_valid(M._panel.win) then
        vim.api.nvim_win_close(M._panel.win, true) -- avoid overlapping the read-only panel
        M._panel = nil
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    local win = vim.api.nvim_open_win(buf, true, bottom_right(summary_lines(staged), {
        title = " Review (?) ",
        focusable = true,
        max_height = 15,
    }))

    local function refresh()
        local lines = summary_lines(staged)
        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].modifiable = false -- read-only: no free-text editing
        vim.api.nvim_win_set_config(win, bottom_right(lines, {
            title = " Review (?) ",
            focusable = true,
            max_height = 15,
        }))
    end

    -- Item under the cursor (one line == one item).
    local function cursor_index()
        return vim.api.nvim_win_get_cursor(win)[1]
    end
    local function reselect(i)
        local n = #staged
        if n == 0 then
            return
        end
        vim.api.nvim_win_set_cursor(win, { math.max(1, math.min(i, n)), 0 })
    end

    local function close()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
        refresh_panel()
    end

    local function delete_item()
        local i = cursor_index()
        if staged[i] then
            table.remove(staged, i)
            if #staged == 0 then
                close()
                return
            end
            refresh()
            reselect(i)
        end
    end
    local function reprompt()
        local i = cursor_index()
        local item = staged[i]
        if not item then
            return
        end
        open_prompt(function(prompt)
            item.prompt = prompt
            refresh()
            reselect(i)
        end, {
            initial = item.prompt,
            context = item.code and vim.split(item.code, "\n") or {},
        })
    end

    local function copy_and_close()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
        M.copy_all() -- copies the whole review, clears staged, refreshes the panel
    end

    -- Floating cheat sheet; any key closes it and returns to the review.
    local function show_help()
        local help = {
            " <CR>      copy review + clear ",
            " dd        delete item ",
            " r         re-prompt item ",
            " ?         this help ",
            " Tab Tab   close review ",
            " Esc       close review ",
        }
        local hbuf = vim.api.nvim_create_buf(false, true)
        vim.bo[hbuf].bufhidden = "wipe"
        vim.api.nvim_buf_set_lines(hbuf, 0, -1, false, help)
        vim.bo[hbuf].modifiable = false
        local hwin = vim.api.nvim_open_win(hbuf, true, centered_help(help))
        local function shut()
            if vim.api.nvim_win_is_valid(hwin) then
                vim.api.nvim_win_close(hwin, true)
            end
        end
        -- Close on any of the common keys.
        for _, k in ipairs({ "?", "q", "<Esc>", "<CR>" }) do
            vim.keymap.set("n", k, shut, { buffer = hbuf, nowait = true })
        end
    end

    local o = { buffer = buf, nowait = true }
    vim.keymap.set("n", "<CR>", copy_and_close, o)
    vim.keymap.set("n", "dd", delete_item, o)
    vim.keymap.set("n", "r", reprompt, o)
    vim.keymap.set("n", "?", show_help, o)
    vim.keymap.set("n", "<Tab><Tab>", close, o) -- toggle the review closed
    vim.keymap.set("n", "<Esc>", close, o)

    refresh()
end

-- Register the opt-in default keymaps from M.config.keymaps.
local function apply_keymaps()
    local k = M.config.keymaps
    if not k then
        return
    end
    if k.add then
        vim.keymap.set("x", k.add, M.add_selection,
            { silent = true, desc = "prompt-reference: add selection to review" })
    end
    if k.review then
        vim.keymap.set("n", k.review, M.review,
            { silent = true, desc = "prompt-reference: open review" })
    end
    if k.copy then
        vim.keymap.set("n", k.copy, M.copy_all,
            { silent = true, desc = "prompt-reference: copy review & clear" })
    end
end

-- Snapshot the default keymaps table so `keymaps = true` can restore them, and
-- so a boolean `keymaps` opt doesn't confuse tbl_deep_extend.
M.defaults_keymaps = vim.deepcopy(M.config.keymaps)

function M.setup(opts)
    opts = opts or {}
    -- `keymaps` may be true (use defaults), false (bind nothing), or a table
    -- (merge over defaults). Resolve it before the deep-merge, which can't mix a
    -- boolean with the default keymaps table.
    local km = opts.keymaps
    opts = vim.deepcopy(opts)
    opts.keymaps = nil
    M.config = vim.tbl_deep_extend("force", M.config, opts)
    if km == true then
        M.config.keymaps = vim.deepcopy(M.defaults_keymaps)
    elseif km == false then
        M.config.keymaps = false
    elseif type(km) == "table" then
        M.config.keymaps = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults_keymaps), km)
    else
        -- keymaps not specified: default to binding nothing (opt-in).
        M.config.keymaps = false
    end
    apply_keymaps()
end

return M
