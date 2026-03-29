mcl_inventory = {}

dofile(minetest.get_modpath(minetest.get_current_modname()) .. "/creative.lua")
dofile(minetest.get_modpath(minetest.get_current_modname()) .. "/survival.lua")

local old_is_creative_enabled = minetest.is_creative_enabled

function minetest.is_creative_enabled(name)
	if old_is_creative_enabled(name) then return true end
	if not name then return false end
	assert(type(name) == "string", "minetest.is_creative_enabled requires a string (the playername) argument.")
	local p = minetest.get_player_by_name(name)
	if p then
		return p:get_meta():get_string("gamemode") == "creative"
	end
	return false
end

---@param player mt.PlayerObjectRef
---@param armor_change_only? boolean
local function set_inventory(player, armor_change_only)
	if minetest.is_creative_enabled(player:get_player_name()) then
		if armor_change_only then
			-- Stay on survival inventory plage if only the armor has been changed
			mcl_inventory.set_creative_formspec(player, 0, 0, nil, nil, "inv")
		else
			mcl_inventory.set_creative_formspec(player, 0, 1)
		end
		return
	end

	player:set_inventory_formspec(mcl_inventory.build_survival_formspec(player))
end

-- Drop items in craft grid and reset inventory on closing
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if fields.quit then
		mcl_util.move_player_list(player, "craft")
		mcl_util.move_player_list(player, "craftresult")
		mcl_util.move_player_list(player, "enchanting_lapis")
		mcl_util.move_player_list(player, "enchanting_item")
		if not minetest.is_creative_enabled(player:get_player_name()) and (formname == "" or formname == "main") then
			set_inventory(player)
		end
	end
end)


function mcl_inventory.update_inventory_formspec(player)
	set_inventory(player)
end

-- Helper to get inventory from location string
local function get_inventory_from_location(location, player)
	if location == "current_player" then
		return player:get_inventory()
	end
	local inv_type, name = location:match("^(%a+):(.+)$")
	if not inv_type then return nil end
	if inv_type == "player" then
		local target_player = minetest.get_player_by_name(name)
		if target_player then
			return target_player:get_inventory()
		end
	elseif inv_type == "node" then
		local pos = minetest.string_to_pos(name)
		if pos then
			return minetest.get_inventory({type = "node", pos = pos}), pos
		end
	elseif inv_type == "detached" then
		return minetest.get_inventory({type = "detached", name = name})
	end
end

-- Hotbar swap logic (Minetest 5.8.0+)
minetest.register_on_player_receive_fields(function(player, formname, fields)
	local key = nil
	for f, _ in pairs(fields) do
		local k = f:match("^key_(%d)$")
		if k then
			key = tonumber(k)
			break
		end
	end

	if not (key and key >= 1 and key <= 9 and fields.hovered_list and fields.hovered_index and fields.hovered_location) then
		return
	end

	local hovered_inv, pos = get_inventory_from_location(fields.hovered_location, player)
	if not hovered_inv then return end

	local hovered_list = fields.hovered_list
	local hovered_index = tonumber(fields.hovered_index) + 1
	local player_inv = player:get_inventory()
	local hotbar_index = key

	-- Rule: If the hovered slot is already the same target hotbar slot, do nothing
	if (fields.hovered_location == "current_player" or fields.hovered_location == "player:" .. player:get_player_name())
			and hovered_list == "main" and hovered_index == hotbar_index then
		return
	end

	local hovered_stack = hovered_inv:get_stack(hovered_list, hovered_index)
	-- Rule: If hovered slot is empty: do nothing
	if hovered_stack:is_empty() then
		return
	end

	-- Additional safety: Don't swap into restricted lists
	if hovered_list == "craftresult" or hovered_list == "craftpreview" then
		return
	end

	local hotbar_stack = player_inv:get_stack("main", hotbar_index)

	-- Security check for nodes
	if pos then
		if minetest.is_protected(pos, player:get_player_name()) then
			return
		end
		local node = minetest.get_node(pos)
		local ndef = minetest.registered_nodes[node.name]
		if ndef then
			if ndef.allow_metadata_inventory_take then
				if ndef.allow_metadata_inventory_take(pos, hovered_list, hovered_index, hovered_stack, player) < hovered_stack:get_count() then
					return
				end
			end
			if not hotbar_stack:is_empty() and ndef.allow_metadata_inventory_put then
				if ndef.allow_metadata_inventory_put(pos, hovered_list, hovered_index, hotbar_stack, player) < hotbar_stack:get_count() then
					return
				end
			end
		end
	end

	-- Perform the swap
	hovered_inv:set_stack(hovered_list, hovered_index, hotbar_stack)
	player_inv:set_stack("main", hotbar_index, hovered_stack)

	-- Trigger on_* callbacks for nodes
	if pos then
		local node = minetest.get_node(pos)
		local ndef = minetest.registered_nodes[node.name]
		if ndef then
			if ndef.on_metadata_inventory_take then
				ndef.on_metadata_inventory_take(pos, hovered_list, hovered_index, hovered_stack, player)
			end
			if not hotbar_stack:is_empty() and ndef.on_metadata_inventory_put then
				ndef.on_metadata_inventory_put(pos, hovered_list, hovered_index, hotbar_stack, player)
			end
		end
	end

	if fields.hovered_location == "current_player" or fields.hovered_location == "player:" .. player:get_player_name() then
		mcl_inventory.update_inventory_formspec(player)
	end
end)

-- Drop crafting grid items on leaving
minetest.register_on_leaveplayer(function(player)
	mcl_util.move_player_list(player, "craft")
	mcl_util.move_player_list(player, "craftresult")
	mcl_util.move_player_list(player, "enchanting_lapis")
	mcl_util.move_player_list(player, "enchanting_item")
end)

minetest.register_on_joinplayer(function(player)
	--init inventory
	local inv = player:get_inventory()

	inv:set_width("main", 9)
	inv:set_size("main", 36)
	inv:set_size("offhand", 1)

	--set hotbar size
	player:hud_set_hotbar_itemcount(9)
	--add hotbar images
	player:hud_set_hotbar_image("mcl_inventory_hotbar.png")
	player:hud_set_hotbar_selected_image("mcl_inventory_hotbar_selected.png")

	-- In Creative Mode, the initial inventory setup is handled in creative.lua
	if not minetest.is_creative_enabled(player:get_player_name()) then
		set_inventory(player)
	end

	--[[ Make sure the crafting grid is empty. Why? Because the player might have
	items remaining in the crafting grid from the previous join; this is likely
	when the server has been shutdown and the server didn't clean up the player
	inventories. ]]
	mcl_util.move_player_list(player, "craft")
	mcl_util.move_player_list(player, "craftresult")
	mcl_util.move_player_list(player, "enchanting_lapis")
	mcl_util.move_player_list(player, "enchanting_item")
end)

---@param player mt.PlayerObjectRef
function mcl_inventory.update_inventory(player)
	local player_name = player:get_player_name()
	local is_gamemode_creative = minetest.is_creative_enabled(player_name)
	if is_gamemode_creative then
		mcl_inventory.set_creative_formspec(player)
	elseif not is_gamemode_creative then
		player:set_inventory_formspec(mcl_inventory.build_survival_formspec(player))
	end
	mcl_meshhand.update_player(player)
end

mcl_gamemode.register_on_gamemode_change(function(player, old_gamemode, new_gamemode)
	set_inventory(player)
end)

mcl_player.register_on_visual_change(mcl_inventory.update_inventory_formspec)
