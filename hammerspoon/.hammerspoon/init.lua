-- local ox = hs.loadSpoon("OutlineX_hs")
--
-- ox.borderWidth = 2
-- ox.borderColor = "#ed8707"
-- ox.borderAlpha = 0.9
-- ox.cornerRadius = 16
-- ox:start()
hs.loadSpoon("Hammerflow")
spoon.Hammerflow.loadFirstValidTomlFile({
	"~/.config/hammerflow/config.toml",
})

-- optionally respect auto_reload setting in the toml config.
if spoon.Hammerflow.auto_reload then
	hs.loadSpoon("ReloadConfiguration")
	-- set any paths for auto reload
	spoon.ReloadConfiguration.watch_paths = { hs.configDir, "~/.config/hammerflow/config.toml" }
	spoon.ReloadConfiguration:start()
end
PaperWM = hs.loadSpoon("PaperWM")
PaperWM.external_bar = { top = 20 }
PaperWM.window_gap = 20
PaperWM.window_filter:setAppFilter("Vivaldi", { rejectTitles = "PiP Video Player" })
spoon.PaperWM.window_filter:rejectApp("Finder")
spoon.PaperWM.window_filter:rejectApp("System Settings")
PaperWM.window_ratios = { 1 / 3, 1 / 2, 2 / 3 }
-- disable mouse centering when switching spaces
PaperWM.center_mouse = true
PaperWM:bindHotkeys({
	-- switch to a new focused window in tiled grid
	focus_left = { "alt", "h" },
	focus_right = { "alt", "l" },
	focus_up = { "alt", "k" },
	focus_down = { "alt", "j" },

	-- switch windows by cycling forward/backward
	-- (forward = down or right, backward = up or left)
	focus_prev = { "alt", "p" },
	focus_next = { "alt", "n" },

	-- move windows around in tiled grid
	swap_left = { { "alt", "shift" }, "h" },
	swap_right = { { "alt", "shift" }, "l" },
	swap_up = { { "alt", "shift" }, "k" },
	swap_down = { { "alt", "shift" }, "j" },

	-- position and resize focused window
	center_window = { "alt", "c" },
	full_width = { "alt", "m" },
	cycle_width = { "alt", "r" },
	reverse_cycle_width = { { "alt", "shift" }, "r" },
	cycle_height = { { "alt", "cmd", "shift" }, "r" },
	reverse_cycle_height = { { "ctrl", "alt", "cmd", "shift" }, "r" },

	-- increase/decrease width
	increase_width = { { "alt", "cmd" }, "l" },
	decrease_width = { { "alt", "cmd" }, "h" },

	-- move focused window into / out of a column
	slurp_in = { { "alt", "shift" }, "i" },
	barf_out = { { "alt", "shift" }, "o" },

	-- move the focused window into / out of the tiling layer
	toggle_floating = { { "alt", "shift" }, "f" },
	-- raise all floating windows on top of tiled windows
	focus_floating = { { "alt", "cmd", "shift" }, "f" },

	-- focus the first / second / etc window in the current space
	focus_window_1 = { "alt", "1" },
	focus_window_2 = { "alt", "2" },
	focus_window_3 = { "alt", "3" },
	focus_window_4 = { "alt", "4" },
	focus_window_5 = { "alt", "5" },
	focus_window_6 = { "alt", "6" },
	focus_window_7 = { "alt", "7" },
	focus_window_8 = { "alt", "8" },
	focus_window_9 = { "alt", "9" },

	-- switch to a new Mission Control space
	switch_space_l = { { "alt", "cmd" }, "," },
	switch_space_r = { { "alt", "cmd" }, "." },
	switch_space_1 = { { "alt", "cmd" }, "1" },
	switch_space_2 = { { "alt", "cmd" }, "2" },
	switch_space_3 = { { "alt", "cmd" }, "3" },
	switch_space_4 = { { "alt", "cmd" }, "4" },
	switch_space_5 = { { "alt", "cmd" }, "5" },
	switch_space_6 = { { "alt", "cmd" }, "6" },
	switch_space_7 = { { "alt", "cmd" }, "7" },
	switch_space_8 = { { "alt", "cmd" }, "8" },
	switch_space_9 = { { "alt", "cmd" }, "9" },

	-- move focused window to a new space and tile
	move_window_1 = { { "alt", "cmd", "shift" }, "1" },
	move_window_2 = { { "alt", "cmd", "shift" }, "2" },
	move_window_3 = { { "alt", "cmd", "shift" }, "3" },
	move_window_4 = { { "alt", "cmd", "shift" }, "4" },
	move_window_5 = { { "alt", "cmd", "shift" }, "5" },
	move_window_6 = { { "alt", "cmd", "shift" }, "6" },
	move_window_7 = { { "alt", "cmd", "shift" }, "7" },
	move_window_8 = { { "alt", "cmd", "shift" }, "8" },
	move_window_9 = { { "alt", "cmd", "shift" }, "9" },
})
PaperWM:start()
