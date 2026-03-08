-- local ox = hs.loadSpoon("OutlineX_hs")
--
-- ox.borderWidth = 4
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
