local mod = get_mod("MyHero")

return {
	name = "My Hero",
	description = mod:localize("mod_description"),
	is_togglable = true,
	is_mutator = false,
	mutator_settings = {},
	options = {
		widgets = {
			{
			  setting_id    = "classic_anims",
			  type          = "checkbox",
			  default_value = false,
			},
			{
			  setting_id      = "background_objects",
			  type            = "dropdown",
			  default_value = "",
			  options = {
				{text = "background_none",   value = ""},
				{text = "background_waystone",   value = "adventure"},
				{text = "background_map", value = "custom_game"},
				{text = "background_deed",  value = "heroic_deeds"},
				{text = "background_equipment",  value = "equipment"},
				{text = "background_talents",  value = "talents"},
				{text = "background_forge",  value = "forge"},
				{text = "background_cosmetics",  value = "cosmetics"},
				{text = "background_system",  value = "system"},
			  },			  
			},			
		}
	}
}