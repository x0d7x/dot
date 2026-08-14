local blend = {}

function blend.colors(bg_color, fg_color, percentage)
	local function hex_to_rgb(hex)
		hex = hex:gsub("#", "")
		return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
	end

	local function rgb_to_hex(r, g, b)
		return string.format("#%02x%02x%02x", math.floor(r), math.floor(g), math.floor(b))
	end

	local bg_r, bg_g, bg_b = hex_to_rgb(bg_color)
	local fg_r, fg_g, fg_b = hex_to_rgb(fg_color)

	local blend = percentage > 1 and percentage / 100 or percentage

	local r = bg_r + (fg_r - bg_r) * blend
	local g = bg_g + (fg_g - bg_g) * blend
	local b = bg_b + (fg_b - bg_b) * blend

	return rgb_to_hex(r, g, b)
end

function blend._282828(color, percentage)
	return blend.colors("#1d2021", color, percentage)
end

_G.blend = blend
