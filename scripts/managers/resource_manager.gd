class_name ResourceManager
extends RefCounted

var main

func _init(main_ref):
        main = main_ref

func on_power_timer_timeout():
        calculate_power()
        gather_resources()

func calculate_power():
        main.resources.power_max_gen = 0.0
        main.resources.power_max_cons = 0.0

        for module in main.built_modules:
                var type_data = main.MODULE_DATABASE.get(module.type)
                if not type_data:
                        continue
                var zone_type = main.zone_manager.get_zone_type(module.pos)
                var category = main.zone_manager.get_module_category(module.type)
                if not main.zone_manager.is_category_allowed(zone_type, category):
                        continue
                var module_stats = type_data.get("stats", {})
                if module_stats:
                        main.resources.power_max_gen += module_stats.get("power_gen", 0.0)
                        main.resources.power_max_cons += module_stats.get("power_cons", 0.0)

        main.resources.power = main.resources.power_max_gen - main.resources.power_max_cons
        print("--- Power Balance: " + str(main.resources.power_max_gen) + " GEN - " + str(main.resources.power_max_cons) + " CONS = " + str(main.resources.power))

func gather_resources():
	var rate = 0
        for module in main.built_modules:
                var type_data = main.MODULE_DATABASE.get(module.type)
                if not type_data:
                        continue
                var zone_type = main.zone_manager.get_zone_type(module.pos)
                var category = main.zone_manager.get_module_category(module.type)
                if not main.zone_manager.is_category_allowed(zone_type, category):
                        continue
                var module_stats = type_data.get("stats", {})
                if module_stats.has("metal_rate"):
                        rate = module_stats.metal_rate
                        if rate > 0 and main.resources.power > main.resources.power_max_cons:
                                main.resources.metal += rate
        print("Gathered " + str(rate) + " metal. Total metal: " + str(main.resources.metal))
