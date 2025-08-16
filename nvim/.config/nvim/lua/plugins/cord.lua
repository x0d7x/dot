return {
	"vyfor/cord.nvim",
	build = ":Cord update",
	opts = {
		display = { theme = "atom", flavor = "dark" },
		editor = {
			client = "vim",
			tooltip = "the quick brown fox jumps over the lazy dog",
		},
		text = {
			editing = "[ Coding a ${filename} ] 🚀",
		},
		variables = true, -- Enable string templates
	},
}
