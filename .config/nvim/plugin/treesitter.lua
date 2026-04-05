local pack = require("core.pack")

pack.add({
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
})

local ensure_installed = {
    "bash", "c", "html", "javascript", "json", "toml", "lua", "luadoc", "luap",
    "markdown", "markdown_inline", "python", "regex", "tsx", "typescript", "vue",
    "vim", "vimdoc", "yaml", "rust", "go", "gomod", "gowork", "gosum", "php", "astro",
}

vim.api.nvim_create_autocmd("FileType", {
    pattern = "*",
    callback = function(args)
        pcall(vim.treesitter.start)
        vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end,
})

vim.api.nvim_create_autocmd("User", {
    pattern = "PackChanged",
    callback = function(args)
        local kind = args.data and args.data.kind
        if kind ~= "install" and kind ~= "update" then
            return
        end

        local name = args.data.spec and args.data.spec.name
        if name ~= "nvim-treesitter" then
            return
        end

        local ts = require("nvim-treesitter")
        local installed = ts.config.get_installed()
        local to_install = vim.tbl_filter(function(parser)
            return not vim.tbl_contains(installed, parser)
        end, ensure_installed)

        if #to_install > 0 then
            ts.install(to_install)
        end
    end,
})
