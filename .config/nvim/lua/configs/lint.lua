local lint = require("lint")
local eslint = lint.linters.eslint_d
lint.linters_by_ft = {
    javascript = { "deno" },
    typescript = { "deno" },
    javascriptreact = { "deno" },
    typescriptreact = { "deno" },
    -- vue = { "eslint_d" },
    -- svelte = { "eslint_d" },
    python = { "pylint" },
    php = { "phpmd" },
}

local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
    group = lint_augroup,
    callback = function()
        lint.try_lint()
    end,
})
