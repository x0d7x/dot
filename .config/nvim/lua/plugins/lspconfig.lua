return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      tailwindcss = {
        -- exclude a filetype from the default_config
        filetypes_exclude = {},
        -- add additional filetypes to the default_config
        filetypes_include = {},
        -- to fully override the default_config, change the below
        -- filetypes = {}
      },
    },
  },
}
