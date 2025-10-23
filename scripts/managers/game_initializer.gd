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
                if json_data is Dictionary:
                        for type_key in json_data.keys():
                                var module_data = json_data[type_key]
                                if module_data.has("atlas_coords"):
                                        var coords_array = module_data.atlas_coords
                                        module_data.atlas_coords = Vector2i(coords_array[0], coords_array[1])
                                main.MODULE_DATABASE[type_key] = module_data
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
                        if x == 0 or x == main.START_BASE_SIZE + 1 or y == 0 or y == main.START_BASE_SIZE + 1:
                                construction_manager.set_module_tile("hull", tile_pos)
                                zone_manager.ensure_zone(tile_pos, zone_manager.get_default_zone_for_category(zone_manager.get_module_category("hull")))

        for x in range(main.START_BASE_SIZE):
                for y in range(main.START_BASE_SIZE):
                        var tile_pos = Vector2i(center_pos.x + x, center_pos.y + y)
                        construction_manager.set_module_tile("floor", tile_pos)
                        zone_manager.ensure_zone(tile_pos, zone_manager.get_default_zone_for_category(zone_manager.get_module_category("floor")))

        var starter_modules := {
                "solar_collector": Vector2i(2, 0),
                "void_drill": Vector2i(1, 0),
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
