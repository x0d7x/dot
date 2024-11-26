local lint = require("lint")
local eslint = lint.linters.eslint_d
lint.linters_by_ft = {
    javascript = { "eslint_d" },
    typescript = { "eslint_d" },
    javascriptreact = { "eslint_d" },
    typescriptreact = { "eslint_d" },
    svelte = { "eslint_d" },
    python = { "pylint" },
    php = { "phpmd" },
}
eslint.args = {
    "--no-warn-ignored", -- <-- this is the key argument
    "--format",
    "json",
    "--stdin",
    "--stdin-filename",
    function()
        return vim.api.nvim_buf_get_name(0)
    end,
}

local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
    group = lint_augroup,
    callback = function()
        lint.try_lint()
    end,
})
