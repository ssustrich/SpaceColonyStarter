class_name GameInitializer
extends RefCounted

var main
var construction_manager
var zone_manager

func _init(main_ref, construction_mgr, zone_mgr):
		main = main_ref
		construction_manager = construction_mgr
		zone_manager = zone_mgr

func load_module_database():
		var file = FileAccess.open("res://blocks/modules.json", FileAccess.READ)
		if FileAccess.get_open_error() == OK:
				var json_string = file.get_as_text()
				var json_data = JSON.parse_string(json_string)
				var hull_rotations;
				if json_data is Dictionary and json_data.has("ship"):
					json_data = json_data.get("ship")
					for type_key in json_data.keys():
						print(type_key)
						var module_data = json_data[type_key]
						
						var shared = module_data.duplicate()
						shared.erase("variants")
						
						if module_data.has("variants"):
							for variant_name in module_data.variants.keys():
								var variant = shared.duplicate(true)
								var variant_overrides = module_data.variants[variant_name]
								if variant_overrides.has("atlas_coords"):
									var arr = variant_overrides.atlas_coords
									variant_overrides.atlas_coords = Vector3i(arr[0], arr[1],arr[2] )
								variant.merge(variant_overrides, true)
								var atlas := Vector3i(variant_overrides.atlas_coords[0], variant_overrides.atlas_coords[1], variant_overrides.atlas_coords[2])
								var module_key := "%s:%s" % [type_key, variant_name]
								main.MODULE_DATABASE[module_key] = variant
								main.MODULE_DATABASE_RLUT[atlas] = {
									"type": type_key,
									"variant": variant_name,
									"module_key": module_key,
								}
						else:
							main.MODULE_DATABASE[type_key] = shared
							main.MODULE_DATABASE_RLUT[shared]=type_key			
					print(str(main.MODULE_DATABASE.keys().size()) + " modules loaded successfully from JSON.")
				else:
						push_error("Error parsing modules.json: Invalid JSON format.")
		else:
				push_error("Error opening modules.json: " + str(FileAccess.get_open_error()))

func setup_starting_base():
		var center_pos = Vector2i(main.START_BASE_POS, main.START_BASE_POS)
		var center_tile_pos = center_pos + Vector2i(main.START_BASE_SIZE/2, main.START_BASE_SIZE/2)
		var center_world_pos = main.tilemap.map_to_local(center_tile_pos)
		main.game_camera.global_position = center_world_pos

		for x in range(main.START_BASE_SIZE + 2):
				for y in range(main.START_BASE_SIZE + 2):
						var tile_pos = Vector2i(center_pos.x + x - 1, center_pos.y + y - 1)
						
						#4 cases 
						if x ==0  and y ==0:
							construction_manager.set_module_tile("hull:corner_nw", tile_pos)
						elif  x == main.START_BASE_SIZE + 1 and y == main.START_BASE_SIZE + 1:
							construction_manager.set_module_tile("hull:corner_se", tile_pos)
						elif  x == 0 and y == main.START_BASE_SIZE + 1:
							construction_manager.set_module_tile("hull:corner_sw", tile_pos)
						elif  x == main.START_BASE_SIZE + 1  and y == 0:
							construction_manager.set_module_tile("hull:corner_ne", tile_pos)
						elif x == 0:
							construction_manager.set_module_tile("hull:edge_west", tile_pos)
						elif x == main.START_BASE_SIZE + 1:
							construction_manager.set_module_tile("hull:edge_east", tile_pos)
						elif y == 0:
							construction_manager.set_module_tile("hull:edge_north", tile_pos)
						elif y == main.START_BASE_SIZE + 1:
							construction_manager.set_module_tile("hull:edge_south", tile_pos)
						#zone_manager.ensure_zone(tile_pos, zone_manager.get_default_zone_for_category(zone_manager.get_module_category("hull")))

		for x in range(main.START_BASE_SIZE):
				for y in range(main.START_BASE_SIZE):
						var tile_pos = Vector2i(center_pos.x + x, center_pos.y + y)
						construction_manager.set_module_tile("floor", tile_pos)
						construction_manager.set_module_tile("floor", tile_pos)
						#zone_manager.ensure_zone(tile_pos, zone_manager.get_default_zone_for_category(zone_manager.get_module_category("floor")))

		var starter_modules := {
				"solar_collector": Vector2i(2, 2),
				"void_drill": Vector2i(2, -1),
		}

		for module_type in starter_modules.keys():
				if not main.MODULE_DATABASE.has(module_type):
						push_error("Starter module missing from database: " + module_type)
						continue

				var module_pos = center_pos + starter_modules[module_type]
				var module_data: Dictionary = main.MODULE_DATABASE[module_type]

				if module_data.get("place_on_hull", false) or module_data.get("layer") == main.LAYER_HULL:
						var existing_tile := GlobalUtils.get_tile_type(main.tilemap, module_pos, main.LAYER_HULL)
						if existing_tile != "hull":
								construction_manager.set_module_tile("hull", module_pos)

				construction_manager.set_module_tile(module_type, module_pos)
				zone_manager.ensure_zone(module_pos, zone_manager.get_default_zone_for_category(zone_manager.get_module_category(module_type)))
