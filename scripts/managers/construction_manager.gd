class_name ConstructionManager
extends RefCounted

var main

func _init(main_ref):
        main = main_ref

func set_build_mode(active: bool, type: String):
        main.is_building = active
        main.blueprint_type = type
        main.is_hull_expanding = (type == "hull_expand")

        if active:
                print("Entering construction mode: Building " + type + ". Left-click to place, Right-click to cancel.")
        else:
                print("Exiting construction mode.")

func handle_construction_placement(target_tile_pos: Vector2i, target_world_pos: Vector2):
        if main.blueprint_type == "hull_expand":
                handle_hull_expansion(target_tile_pos)
                return

        var type_data = main.MODULE_DATABASE.get(main.blueprint_type)
        if not type_data:
                push_error("Cannot place blueprint: Unknown type " + main.blueprint_type)
                return

        var cost = type_data.get("cost", {})
        for resource_name in cost.keys():
                if main.resources.get(resource_name, 0) < cost[resource_name]:
                        print("Cannot place blueprint: Insufficient " + resource_name + " (" + str(cost[resource_name]) + " needed).")
                        return

        var target_tile_type = GlobalUtils.get_tile_type(main.tilemap, target_tile_pos, main.LAYER_HULL)
        if type_data.get("place_on_hull", false):
                if target_tile_type != "hull":
                        print("Cannot place " + main.blueprint_type + ": Must be placed on an existing Hull section.")
                        return
                main.tilemap.set_cell(main.LAYER_HULL, target_tile_pos, -1)
        else:
                if target_tile_type != "":
                        print("Cannot place blueprint: Tile is already occupied or reserved.")
                        return
                if not GlobalUtils.is_adjacent_to_floor(main.tilemap, target_tile_pos, main.LAYER_FLOOR):
                        print("Cannot place blueprint: Must be adjacent to an existing floor tile.")
                        return

        GlobalUtils._set_layer_cell(main.tilemap, main.LAYER_BLUEPRINT, target_tile_pos, type_data.atlas_coords)

        for resource_name in cost.keys():
                main.resources[resource_name] -= cost[resource_name]

        print("Blueprint placed for " + main.blueprint_type + " at " + str(target_tile_pos) + ". Metal remaining: " + str(main.resources.metal))

func handle_hull_expansion(target_tile_pos: Vector2i):
        var floor_data = main.MODULE_DATABASE["floor"]
        var cost = floor_data.get("cost", {})

        for resource_name in cost.keys():
                if main.resources.get(resource_name, 0) < cost[resource_name]:
                        print("Cannot expand hull: Insufficient " + resource_name + " (" + str(cost[resource_name]) + " needed).")
                        return

        var target_tile_type = GlobalUtils.get_tile_type(main.tilemap, target_tile_pos, main.LAYER_HULL)
        if target_tile_type != "hull":
                print("Cannot expand hull: Must click on an existing gray hull block.")
                return

        set_module_tile("floor", target_tile_pos)

        var neighbors = [
                Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
                Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
        ]

        for offset in neighbors:
                var neighbor_pos = target_tile_pos + offset
                var neighbor_type = GlobalUtils.get_tile_type(main.tilemap, neighbor_pos, main.LAYER_HULL)
                if neighbor_type == "":
                        set_module_tile("hull", neighbor_pos)

        for resource_name in cost.keys():
                main.resources[resource_name] -= cost[resource_name]

        print("Hull expanded instantly at " + str(target_tile_pos) + ". Metal remaining: " + str(main.resources.metal))
        set_build_mode(false, "")

func set_module_tile(type: String, tile_pos: Vector2i):
        var data = main.MODULE_DATABASE.get(type)
        if not data:
                push_error("Attempted to place unknown module type: " + type)
                return

        GlobalUtils._set_layer_cell(main.tilemap, data.layer, tile_pos, data.atlas_coords)

        var existing_index = -1
        for i in range(main.built_modules.size()):
                if main.built_modules[i].pos == tile_pos:
                        existing_index = i
                        break

        var new_module = {
                "type": type,
                "pos": tile_pos,
                "layer": data.layer
        }

        if existing_index != -1:
                main.built_modules[existing_index] = new_module
        else:
                main.built_modules.append(new_module)

func finalize_construction(blueprint_type: String, tile_pos: Vector2i):
        var module_to_build = blueprint_type.trim_prefix("build_")
        main.tilemap.set_cell(main.LAYER_BLUEPRINT, tile_pos, -1)
        set_module_tile(module_to_build, tile_pos)
        print("Construction complete: " + module_to_build + " built at " + str(tile_pos))
        main.resource_manager.calculate_power()
