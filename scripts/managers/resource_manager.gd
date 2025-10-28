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
                var dic =  main.built_modules
                print(dic)
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
                                        print(module_stats)
                                        var power_generated := _get_stat_value(module_stats, "power_gen")
                                        main.resources.power_max_gen += power_generated
                                        main.resources.power_max_cons += _get_stat_value(module_stats, "power_cons")

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
                if module_stats:
                        var metal_rate := _get_stat_value(module_stats, "metal_rate")
                        if metal_rate > 0 and main.resources.power > main.resources.power_max_cons:
                                main.resources.metal += metal_rate
                                rate = metal_rate
        print("Gathered " + str(rate) + " metal. Total metal: " + str(main.resources.metal))

static func _get_stat_value(stats: Dictionary, key: String, default_value: float = 0.0) -> float:
        if stats.is_empty():
                return default_value

        var value = stats.get(key, null)
        if value == null:
                value = stats.get(StringName(key), null)

        if value == null:
                return default_value

        return float(value)
