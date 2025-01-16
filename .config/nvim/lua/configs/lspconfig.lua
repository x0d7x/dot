local on_attach = require("nvchad.configs.lspconfig").on_attach
local on_init = require("nvchad.configs.lspconfig").on_init
local capabilities = require("nvchad.configs.lspconfig").capabilities
local lspconfig = require("lspconfig")
local mason_registry = require("mason-registry")

-- list of all servers configured.
lspconfig.servers = {
    "denols",
    "lua_ls",
    "html",
    "cssls",
    "taplo",
    "emmet_ls",
    "tailwindcss",
    "intelephense",
    "bashls",
    "astro",
}

-- list of servers configured with default config.
local default_servers = {
    "denols",
    "html",
    "cssls",
    "emmet_ls",
    "bashls",
    "tailwindcss",
    "taplo",
    "intelephense",
    "astro",
}

-- lsps with default config
for _, lsp in ipairs(default_servers) do
    lspconfig[lsp].setup({
        on_attach = on_attach,
        on_init = on_init,
        capabilities = capabilities,
    })
end
lspconfig.lua_ls.setup({
    on_attach = on_attach,
    on_init = on_init,
    capabilities = capabilities,

    settings = {
        Lua = {
            diagnostics = {
                -- enable = false, -- Disable all diagnostics from lua_ls
                -- globals = { "vim" },
            },
            workspace = {
                library = {
                    vim.fn.expand("$VIMRUNTIME/lua"),
                    vim.fn.expand("$VIMRUNTIME/lua/vim/lsp"),
                    vim.fn.stdpath("data") .. "/lazy/ui/nvchad_types",
                    vim.fn.stdpath("data") .. "/lazy/lazy.nvim/lua/lazy",
                    "${3rd}/luv/library",
                },
                maxPreload = 100000,
                preloadFileSize = 10000,
            },
        },
    },
})
lspconfig.tailwindcss.setup({
    on_attach = on_attach,
    on_init = on_init,
    capabilities = capabilities,
    -- to make bun || deno install it
    filetypes = {
        "css",
        "javascript",
        "javascriptreact",
        "typescript",
        "typescriptreact",
        "vue",
        "svelte",
        "markdown",
        "mdx",
        "astro",
        "astro-markdown",
    },
})
lspconfig.astro.setup({
    on_attach = on_attach,
    on_init = on_init,
    capabilities = capabilities,
    filetypes = { "astro" },
    init_options = {
        typescript = {},
    },
})
lspconfig.denols.setup({
    on_attach = on_attach,
    on_init = on_init,
    init_options = {
        lint = true,
        unstable = false,
        -- config = "./deno.jsonc",
        suggest = {
            imports = {
                hosts = {
                    ["https://deno.land"] = true,
                    ["https://cdn.nest.land"] = true,
                    ["https://crux.land"] = true,
                },
            },
        },
    },
    capabilities = capabilities,
    filetypes = {
        "javascript",
        "javascriptreact",
        "javascript.jsx",
        "typescript",
        "typescriptreact",
        "typescript.tsx",
        "markdown",
        -- "mdx",
    },
})
lspconfig.emmet_ls.setup({
    on_init = on_init,
    on_attach = on_attach,
    capabilities = capabilities,
    cmd = { "bun", "run", "--bun", "emmet-ls", "--stdio" },
    filetypes = {
        "astro",
        "css",
        "eruby",
        "html",
        "htmldjango",
        "javascriptreact",
        "less",
        "pug",
        "sass",
        "scss",
        "svelte",
        "typescriptreact",
        "vue",
        "htmlangular",
    },
})
