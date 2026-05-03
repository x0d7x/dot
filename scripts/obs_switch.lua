local scenes = {}
local current_index = 1

function script_description()
	return "يبدل بين المشاهد بالتسلسل ويرسل تنبيه في macOS عند التغيير."
end

function get_scene_names()
	scenes = {}
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			local source_id = obs.obs_source_get_id(source)
			if source_id == "scene" then
				local name = obs.obs_source_get_name(source)
				table.insert(scenes, name)
			end
		end
	end
	obs.source_list_release(sources)
end

function send_mac_notification(scene_name)
	local command = string.format(
		'osascript -e \'display notification "Switched to: %s" with title "OBS Scene Changed"\'',
		scene_name:gsub("'", "\\'")
	)
	os.execute(command)
end

function next_scene()
	if #scenes == 0 then
		get_scene_names()
	end
	current_index = current_index + 1
	if current_index > #scenes then
		current_index = 1
	end
	local scene_name = scenes[current_index]
	local scene = obs.obs_get_source_by_name(scene_name)
	if scene ~= nil then
		obs.obs_frontend_set_current_scene(scene)
		obs.obs_source_release(scene)
		send_mac_notification(scene_name)
	end
end

function script_load(settings)
	get_scene_names()
	hotkey_id =
		obs.obs_hotkey_register_frontend("next_scene_hotkey", "التبديل للمشهد التالي", next_scene)
	local hotkey_array = obs.obs_data_get_array(settings, "next_scene_hotkey")
	obs.obs_hotkey_load(hotkey_id, hotkey_array)
	obs.obs_data_array_release(hotkey_array)
end

function script_save(settings)
	local hotkey_array = obs.obs_hotkey_save(hotkey_id)
	obs.obs_data_set_array(settings, "next_scene_hotkey", hotkey_array)
	obs.obs_data_array_release(hotkey_array)
end
