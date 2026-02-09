local wezterm = require("wezterm")
local mux = wezterm.mux

-- ========= First window only: auto-start tmux (like your Kitty shell line) =========
-- Launches tmux automatically only in the first WezTerm window.
-- Any additional tabs/windows will open with plain zsh.
wezterm.on("gui-startup", function(cmd)
	-- Open a single window running tmux
	local tab, pane, window = mux.spawn_window({
		args = {
			"zsh",
			"-i",
			"-c",
			'if command -v tmux >/dev/null 2>&1 && [ -z "$TMUX" ]; then tmux attach || tmux new -s Dev; else exec zsh; fi',
		},
	})
	-- (Optional) Maximize the window
	-- window:gui_window():maximize()
end)

return {
	-- =================== Fonts ===================
	font = wezterm.font_with_fallback({
		{
			family = "DepartureMono Nerd Font Mono",
			weight = "Bold",
		},
	}),
	font_size = 17,
	-- line_height = 1.2,

	-- =================== Cursor ===================
	-- WezTerm doesn’t support trail, but we use smooth blinking animation
	default_cursor_style = "BlinkingBlock", -- Options: Block / SteadyBlock / BlinkingBar / BlinkingUnderline ...
	cursor_blink_rate = 600,
	cursor_blink_ease_in = "EaseInOut",
	cursor_blink_ease_out = "EaseInOut",
	animation_fps = 120, -- Smoother animation refresh rate
	max_fps = 120,

	-- =================== Colors / Theme ===================
	-- To list all themes: wezterm ls-colorschemes
	color_scheme = "Gruvbox dark, hard (base16)", -- Safe fallback if "Black Metal" not found
	colors = {
		cursor_bg = "white",
	},

	-- =================== Background (blur + opacity) ===================
	window_background_opacity = 0.8,
	macos_window_background_blur = 30,

	-- =================== Decorations / Titlebar ===================
	window_decorations = "RESIZE",
	-- hide the tab bar if only one tab
	hide_tab_bar_if_only_one_tab = true,

	-- =================== Padding ===================
	window_padding = {
		left = 8,
		right = 8,
		top = 6,
		bottom = 6,
	},

	-- =================== Bells / Sounds ===================
	audible_bell = "Disabled",

	-- =================== macOS Option-as-Alt ===================
	send_composed_key_when_left_alt_is_pressed = true,
	send_composed_key_when_right_alt_is_pressed = true,

	-- =================== Behavior ===================
	hide_mouse_cursor_when_typing = true,
	-- never askee to confirm closing a window
	window_close_confirmation = "NeverPrompt",
	-- Preferred default shell for new windows (after the first)
	default_prog = { "/bin/zsh" },
}
