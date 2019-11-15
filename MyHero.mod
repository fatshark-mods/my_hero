return {
	run = function()
		fassert(rawget(_G, "new_mod"), "MyHero must be lower than Vermintide Mod Framework in your launcher's load order.")

		new_mod("MyHero", {
			mod_script       = "scripts/mods/MyHero/MyHero",
			mod_data         = "scripts/mods/MyHero/MyHero_data",
			mod_localization = "scripts/mods/MyHero/MyHero_localization"
		})
	end,
	packages = {
		"resource_packages/MyHero/MyHero"
	}
}
