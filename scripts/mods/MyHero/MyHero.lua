--[[
                     __  __                         
 /'\_/`\            /\ \/\ \                        
/\      \  __  __   \ \ \_\ \     __   _ __   ___   
\ \ \__\ \/\ \/\ \   \ \  _  \  /'__`\/\`'__\/ __`\ 
 \ \ \_/\ \ \ \_\ \   \ \ \ \ \/\  __/\ \ \//\ \L\ \
  \ \_\\ \_\/`____ \   \ \_\ \_\ \____\\ \_\\ \____/
   \/_/ \/_/`/___/> \   \/_/\/_/\/____/ \/_/ \/___/ 
               /\___/                               
               \/__/                                
	SkacikPL(2018) - https://www.skacikpl.pl
--]]
--Uncommented parts of the code are default code of the function.
local mod = get_mod("MyHero")
mod:dofile("scripts/mods/MyHero/MyHero_share_view") --Init the share view UI.
local DEFAULT_ANGLE = math.degrees_to_radians(0) --Port some locals from original script
local camera_position_by_character = {
	witch_hunter = {
		z = 0.4,
		x = 0,
		y = 0.8
	},
	bright_wizard = {
		z = 0.2,
		x = 0,
		y = 0.4
	},
	dwarf_ranger = {
		z = 0,
		x = 0,
		y = 0
	},
	wood_elf = {
		z = 0.16,
		x = 0,
		y = 0.45
	},
	empire_soldier = {
		z = 0.4,
		x = 0,
		y = 1
	},
	empire_soldier_tutorial = {
		z = 0.4,
		x = 0,
		y = 1
	}
} --Ditto.
local definitions = local_require("scripts/ui/views/character_selection_view/character_selection_view_definitions") --Some imports to feed back to OG system.
local attachments = definitions.attachments --Ditto.
local requestedanimation = nil --Declare anim variable to play if not nil.
local requestedfacialanimation = nil --Ditto.
local requesteddialogueanimation = nil --Ditto.

--[[
	Functions
--]]

local function Play_sound(event_name) --Play given sound event.
	local world = Managers.world:world("level_world")
	local wwise_world = Managers.world:wwise_world(world) 
	wwise_world:trigger_event(event_name)
end

--[[
	Hooks
--]]
--We literally override entire function to comment out single line. FFS FS.
mod:hook(MenuWorldPreviewer, "_load_hero_unit", function (func, self, profile_name, career_index, state_character, callback, optional_scale, camera_move_duration, optional_skin, ...)

	self.camera_xy_angle_target = DEFAULT_ANGLE

	self:_unload_all_packages()

	camera_move_duration = camera_move_duration or 0.01
	local character_camera_positions = self._character_camera_positions
	local new_character_position = character_camera_positions[profile_name]

	self:set_character_axis_offset("x", new_character_position.x, camera_move_duration, math.easeOutCubic)
	self:set_character_axis_offset("y", new_character_position.y, camera_move_duration, math.easeOutCubic)
	self:set_character_axis_offset("z", new_character_position.z, camera_move_duration, math.easeOutCubic)

	local world = self.world
	local profile_index = FindProfileIndex(profile_name)
	local profile = SPProfiles[profile_index]
	local career = profile.careers[career_index]
	local career_name = career.name
	local skin_item = BackendUtils.get_loadout_item(career_name, "slot_skin")
	local item_data = skin_item and skin_item.data
	local skin_name = optional_skin  or (item_data and item_data.name) or career.base_skin

	if state_character then
	--	skin_name = career.base_skin -Need to comment that, weird choice. Body skins would've been totally okay either way.
	end

	self._current_career_name = career_name
	self.character_unit_skin_data = nil
	local package_names = {}
	local skin_data = Cosmetics[skin_name]
	local unit_name = skin_data.third_person
	local material_changes = skin_data.material_changes
	package_names[#package_names + 1] = unit_name

	if material_changes then
		local material_package = material_changes.package_name
		package_names[#package_names + 1] = material_package
	end

	local data = {
		career_index = career_index,
		num_loaded_packages = 0,
		career_name = career_name,
		skin_data = skin_data,
		optional_scale = optional_scale,
		package_names = package_names,
		num_packages = #package_names,
		callback = callback
	}

	self:_load_packages(package_names)

self._hero_loading_package_data = data

end)

--Just adding stuff for wiping spawned attachments between spawns.
mod:hook(CharacterSelectionStateCharacter, "_spawn_hero_unit", function (func, self, hero_name, ...) 

	local world_previewer = self.world_previewer
	local career_index = self._selected_career_index
	local callback = callback(self, "cb_hero_unit_spawned", hero_name)

	for i = 1, #self.parent.attachment_units, 1 do --This feeds to the old and unused system but what the hell if it's still there.
		local unit = self.parent.attachment_units[i]

		table.remove(self.parent.attachment_units, i)
		if Unit.alive(unit) then World.destroy_unit(world_previewer.world, unit) end
	end		
	
	world_previewer:request_spawn_hero_unit(hero_name, career_index, true, callback, nil, 0.5)

end)

--Expand equipment spawning for hero select screen unit to load actual player items when applicable.
mod:hook(CharacterSelectionStateCharacter, "cb_hero_unit_spawned", function (func, self, hero_name, ...)

	local world_previewer = self.world_previewer
	local career_index = self._selected_career_index
	local profile_index = FindProfileIndex(hero_name)
	local profile = SPProfiles[profile_index]
	local careers = profile.careers
	local career_settings = careers[career_index]
	local preview_animation = career_settings.preview_animation
	local preview_wield_slot = career_settings.preview_wield_slot
	local preview_items = career_settings.preview_items
	local kerilian_arrow_unit = "units/weapons/player/wpn_we_quiver_t1/wpn_we_arrow_t1_3p"

	if preview_items then
		for _, item_data in ipairs(preview_items) do
			local item_name = item_data.item_name
			local item_template = ItemMasterList[item_name]
			local slot_type = item_template.slot_type
			local slot_names = InventorySettings.slot_names_by_type[slot_type]
			local slot_name = slot_names[1]
			local slot = InventorySettings.slots_by_name[slot_name]
			if (slot_name == "slot_melee" or slot_name == "slot_ranged" or slot_name == "slot_grenade" or slot_name == "slot_potion") and self.parent.issharewindow then slot_name = ScriptUnit.extension(Managers.player:local_player().player_unit, "inventory_system"):get_wielded_slot_name() end
			local slot = InventorySettings.slots_by_name[slot_name]
			local player_item_name = nil --We need to get the stuff that player has equipped on given career in given slot
			local career = profile.careers[career_index] --Ditto.
			local career_name = career.name --Ditto.
			local player_item = BackendUtils.get_loadout_item(career_name, slot_name)
			local item_data = (player_item and player_item.data) or ScriptUnit.extension(Managers.player:local_player().player_unit, "inventory_system"):get_item_data(slot_name) --Ditto.
			local backend_id = nil
			if player_item ~= nil then backend_id = player_item.backend_id end
			
			
			player_item_name = item_data and item_data.name
			local weapon_template_name = item_data and item_data.template
			local weapon_template = Weapons[weapon_template_name]
			

			if weapon_template ~= nil then
				if weapon_template.ammo_data ~= nil then
					if weapon_template.ammo_data.ammo_unit_3p ~= nil then kerilian_arrow_unit = weapon_template.ammo_data.ammo_unit_3p end --Get arrow name for Kerilian
				end
			end
			
			if slot_name == "slot_hat" and player_item_name ~= nil then
				world_previewer:equip_item(player_item_name, slot) --ALWAYS equip player hat.
			end			
			
			if not self.parent.issharewindow then
				if (slot_name == "slot_melee" or slot_name == "slot_ranged") and not (mod:get("classic_anims") and career_settings.name == "wh_captain") then --We're being selective here, if player has currently equipped same weapon as the one in preview, use his for the skin flair. Otherwise use default one in order to not mess with animations. Also don't give weapons to classic WHC.
				
				if player_item_name == item_name then
					world_previewer:equip_item(item_name, slot, backend_id)	-- If we're using players weapon, provide ID so it uses a skin.		
				else
					world_previewer:equip_item(item_name, slot) -- In other case use default instance of the weapon.
				end
				
				end
			
			else
				if slot_name == "slot_melee" or slot_name == "slot_ranged" then
					world_previewer:equip_item(player_item_name, slot, backend_id)
					world_previewer:wield_weapon_slot(string.sub(slot_name, 6))
					if requestedanimation ~= nil then Unit.animation_event(self.world_previewer.character_unit, requestedanimation) requestedanimation = nil end
					if requestedfacialanimation ~= nil then Unit.animation_event(self.world_previewer.character_unit, requestedfacialanimation) requestedfacialanimation = nil end
					if requesteddialogueanimation ~= nil then Unit.animation_event(self.world_previewer.character_unit, requesteddialogueanimation) requesteddialogueanimation = nil end
					Unit.animation_event(self.world_previewer.character_unit, "lookat_on")
				end
			end
		end

		if preview_wield_slot and not self.parent.issharewindow then 
			world_previewer:wield_weapon_slot(preview_wield_slot)
		end
	end
	
	--Classic anim overrides and arrow attachment spawning for Waywatcher.
	if not self.parent.issharewindow then
		if mod:get("classic_anims") and (career_settings.name == "dr_ironbreaker" or career_settings.name == "es_mercenary" or career_settings.name == "we_waywatcher" or career_settings.name == "wh_captain" or career_settings.name == "bw_scholar" or career_settings.name == "bw_adept") then
			preview_animation = "select_accept_start"
			Unit.animation_event(self.world_previewer.character_unit, "select_hover_loop")
			Unit.set_local_position(self.world_previewer.character_unit, 0, Vector3(0,-1.2,0))
			
			if career_settings.name == "we_waywatcher" then
				local attached_unit_name = kerilian_arrow_unit
				local linking = AttachmentNodeLinking.arrow.third_person.wielded
				local attached_unit = World.spawn_unit(world_previewer.world, attached_unit_name)
				Unit.set_unit_visibility(attached_unit, false) --Probably could look prettier if i wasn't using existing/defunct system.

				if Unit.has_lod_object(attached_unit, "lod") then
					local lod_object = Unit.lod_object(attached_unit, "lod")

					LODObject.set_static_select(lod_object, 0)
				end

				local scene_graph_links = {}
				GearUtils.link(world_previewer.world, linking, scene_graph_links, self.world_previewer.character_unit, attached_unit)

				self.parent.attachment_units[#self.parent.attachment_units + 1] = attached_unit

				Unit.flow_event(attached_unit, "lua_wield")		
			end
		end
		
		if preview_animation then
			self.world_previewer:play_character_animation(preview_animation)
			
			--By default anims play the sounds so we need to play them manually for overriden anims.
			if mod:get("classic_anims") then
				if career_settings.name == "dr_ironbreaker" then Play_sound("Play_hud_career_presentation_dwarf_ironbreaker") end
				if career_settings.name == "es_mercenary" then Play_sound("Play_hud_career_presentation_mercenary") end
				if career_settings.name == "we_waywatcher" then Play_sound("Play_hud_career_presentation_elf_waywatcher") end
				if career_settings.name == "wh_captain" then Play_sound("Play_hud_career_presentation_witch_hunter_captain") end
				if career_settings.name == "bw_scholar" then Play_sound("Play_hud_career_presentation_scholar") end
				if career_settings.name == "bw_adept" then Play_sound("Play_hud_career_presentation_adept") end
				
				for i = 1, #self.parent.attachment_units, 1 do
					local unit = self.parent.attachment_units[i]
					Unit.set_unit_visibility(unit, true)
				end					
				
			end
		end
	
	end

end)

--Pretty much same stuff for the main menu you see before entering the keep after booting the game.
mod:hook(StartMenuStateOverview, "cb_hero_unit_spawned", function (func, self, hero_name, ...)

	local world_previewer = self.world_previewer
	local career_index = self.career_index
	local profile_index = FindProfileIndex(hero_name)
	local profile = SPProfiles[profile_index]
	local careers = profile.careers
	local career_settings = careers[career_index]
	local preview_idle_animation = career_settings.preview_idle_animation
	local preview_wield_slot = career_settings.preview_wield_slot
	local preview_items = career_settings.preview_items

	if preview_items then
		for _, item_data in ipairs(preview_items) do
			local item_name = item_data.item_name
			local item_template = ItemMasterList[item_name]
			local slot_type = item_template.slot_type
			local slot_names = InventorySettings.slot_names_by_type[slot_type]
			local slot_name = slot_names[1]
			local slot = InventorySettings.slots_by_name[slot_name]
			local player_item_name = nil --We need to get the stuff that player has equipped on given career in given slot
			local career = profile.careers[career_index] --Ditto.
			local career_name = career.name --Ditto.
			local player_item = BackendUtils.get_loadout_item(career_name, slot_name) --Ditto.	
			--local item_data = player_item and player_item.data --Ditto.
			local backend_id = player_item.backend_id--Ditto.
			
			player_item_name = item_data and item_data.name
			
			
			if slot_name == "slot_hat" and player_item_name ~= nil then
				world_previewer:equip_item(player_item_name, slot) --ALWAYS equip player hat.
			end			
			
			if (slot_name == "slot_melee" or slot_name == "slot_ranged") and not (mod:get("classic_anims") and career_settings.name == "wh_captain") then --We're being selective here, if player has currently equipped same weapon as the one in preview, use his for the skin flair. Otherwise use default one in order to not mess with animations. Also don't give weapons to classic WHC.
			
			if player_item_name == item_name then
				world_previewer:equip_item(item_name, slot, backend_id)	-- If we're using players weapon, provide ID so it uses a skin.		
			else
				world_previewer:equip_item(item_name, slot) -- In other case use default instance of the weapon.
			end
			
			end
		end

		if preview_wield_slot and not ( mod:get("classic_anims") and career_settings.name == "wh_captain" ) then
			world_previewer:wield_weapon_slot(preview_wield_slot)
		end
	end
	
	--Simple override with VT1 idle anim.
	if mod:get("classic_anims") and (career_settings.name == "dr_ironbreaker" or career_settings.name == "es_mercenary" or career_settings.name == "we_waywatcher" or career_settings.name == "wh_captain" or career_settings.name == "bw_scholar" or career_settings.name == "bw_adept") then
		preview_idle_animation = "select_accept_end"
		Unit.animation_event(self.world_previewer.character_unit, "select_hover_loop")	
	end

	if preview_idle_animation and not(mod:get("classic_anims") and (career_settings.name == "dr_ironbreaker" or career_settings.name == "es_mercenary" or career_settings.name == "we_waywatcher" or career_settings.name == "wh_captain" or career_settings.name == "bw_scholar" or career_settings.name == "bw_adept")) then
		self.world_previewer:play_character_animation(preview_idle_animation)
	end

end)

mod:hook(CharacterSelectionStateCharacter, "draw", function (func, self, dt, ...)
	local ui_top_renderer = self.ui_top_renderer
	local ui_scenegraph = self.ui_scenegraph
	local input_manager = self.input_manager
	local parent = self.parent
	local input_service = self:input_service()
	local render_settings = self.render_settings
	local gamepad_active = Managers.input:is_device_active("gamepad")
	self._widgets_by_name.bottom_panel.content.visible = gamepad_active

	UIRenderer.begin_pass(ui_top_renderer, ui_scenegraph, input_service, dt, nil, render_settings)
	
	if not parent.issharewindow then
	for _, widget in ipairs(self._widgets) do
		UIRenderer.draw_widget(ui_top_renderer, widget)
	end

		for _, widget in ipairs(self._hero_widgets) do
			UIRenderer.draw_widget(ui_top_renderer, widget)
		end

		for _, widget in ipairs(self._hero_icon_widgets) do
			UIRenderer.draw_widget(ui_top_renderer, widget)
		end
		
		else
				
		local hero_name = nil --Declare some empty stuff in case player wants to see the levels of other players.
		local hero_attributes = nil --Ditto.
		local experience = 0 --Ditto.
		local level_new, _, _, extra_levels = 0 --Ditto.
		local is_max_level = false --Ditto.
		local TotalLevel = 0 --Ditto.

		
		hero_name = Managers.player:local_player():profile_display_name() --Get profile.
		hero_attributes = Managers.backend:get_interface("hero_attributes") --Get backend interface for attributes.
		experience = hero_attributes:get(hero_name, "experience") or 0 --Get EXP amount.
		level_new, _, _, extra_levels = ExperienceSettings.get_level(experience) --Current visible and overflow levels.
		is_max_level = level_new == ExperienceSettings.max_level --Are we level 30?
		TotalLevel = level_new --We're below 30.
		if is_max_level and extra_levels and extra_levels > 0 then -- We're 30 or above.
			TotalLevel = TotalLevel + extra_levels --Set final level amount to show overflowing levels.
		end		
	
		UIRenderer.draw_widget(ui_top_renderer, self._widgets_by_name.hero_info_panel_glow)
		UIRenderer.draw_widget(ui_top_renderer, self._widgets_by_name.hero_info_panel)
		UIRenderer.draw_widget(ui_top_renderer, self._widgets_by_name.hero_info_level_bg)
		self._widgets_by_name.info_career_name.content.text = Steam.user_name(Managers.player:local_player().peer_id)
		self._widgets_by_name.info_hero_name.style.text.word_wrap = false
		self._widgets_by_name.info_hero_name.style.text_shadow.word_wrap = false
		self._widgets_by_name.info_hero_name.style.text.dynamic_font_size = true
		self._widgets_by_name.info_hero_name.style.text_shadow.dynamic_font_size = true		
		self._widgets_by_name.info_hero_name.content.text = Localize(ItemMasterList[ScriptUnit.extension(Managers.player:local_player().player_unit, "cosmetic_system"):get_equipped_frame_name()].display_name) .. "\n" .. Localize(SPProfiles[Managers.player:local_player():profile_index()].careers[self._career_index].display_name) .. ", " .. Localize(SPProfiles[Managers.player:local_player():profile_index()].character_name)
		self._widgets_by_name.info_hero_level.content.text = TotalLevel
		UIRenderer.draw_widget(ui_top_renderer, self._widgets_by_name.info_career_name)
		UIRenderer.draw_widget(ui_top_renderer, self._widgets_by_name.info_hero_name)
		UIRenderer.draw_widget(ui_top_renderer, self._widgets_by_name.info_hero_level)
		
		local viewport = self.world_previewer.viewport
		local camera = ScriptViewport.camera(viewport)
		local position = Camera.local_position(camera)
		local character_unit = self.world_previewer.character_unit
		if character_unit ~= nil then
			local aim_constraint_anim_var = Unit.animation_find_constraint_target(character_unit, "aim_constraint_target")

			Unit.animation_set_constraint_target(character_unit, aim_constraint_anim_var, position)		
		end	
	end

	if not self._draw_video_next_frame then
		if self._video_widget and not self._prepare_exit then
			if not self._video_created and not parent.issharewindow then
				UIRenderer.draw_widget(ui_top_renderer, self._video_widget)
			else
				self._video_created = nil
			end
		end
	elseif self._draw_video_next_frame then
		self._draw_video_next_frame = nil
	end

	UIRenderer.end_pass(ui_top_renderer)

	if gamepad_active then
		self.menu_input_description:draw(ui_top_renderer, dt)
	end
end)

local view_data = {
  -- Any name may be chosen, but it has to be unique among all registered views
  view_name = "myhero_share_view",
  view_settings = {
    init_view_function = function (ingame_ui_context)
      return MyHeroShareView:new(ingame_ui_context)
    end,
    active = {
      inn = true,
      ingame = false,
    },
    -- There is no check for `nil` in `mod:register_new_views`, so even if empty, these have to be defined
    blocked_transitions = {
      inn = {},
      ingame = {},
    },
    -- `settings_id`/`setting_name` which defines the keybind
    --hotkey_name = "",
    -- has to be same value as the keybind setting's `action_name`
    --hotkey_action_name = "",
    -- Some name that has to match with the key in `view_transitions`
    --hotkey_transition_name = "spf_lore_view",
  },
  view_transitions = {
    myhero_share_view = function (self)
      -- Should match with `view_data.view_name`
      self.current_view = "myhero_share_view"
    end,
  }
}

--mod:register_new_view(view_data)
mod:register_view(view_data)

mod.ShareMenu = function(requestedanim, requestedfacialanim, requesteddialoganim)
	if not Managers.player:local_player().network_manager.matchmaking_manager._ingame_ui.is_in_inn or Managers.player:local_player().network_manager.matchmaking_manager._ingame_ui.current_view ~= nil then return end
	requestedanimation = requestedanim
	requestedfacialanimation = requestedfacialanim
	requesteddialogueanimation = requesteddialoganim
	Managers.player:local_player().network_manager.matchmaking_manager._ingame_ui:handle_transition("myhero_share_view")
end

mod:command("sharemyhero", "Share your hero build!", mod.ShareMenu)