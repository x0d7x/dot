return {
  "mistricky/codesnap.nvim",
  build = "make",
  keys = {
    { "<leader>cp", "<cmd>CodeSnap<cr>", mode = "x", desc = "Save selected code snapshot into clipboard" },
    { "<leader>cP", "<cmd>CodeSnapASCII<cr>", mode = "x", desc = "make ascii snapshot" },
  },
  opts = {
    save_path = "~/Developer/codepic",
    has_breadcrumbs = true,
    bg_theme = "peach",
    watermark = "@x0d7x",
  },
}
