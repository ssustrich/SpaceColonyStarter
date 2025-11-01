class_name CrewManager
extends RefCounted

var main
var construction_manager

func _init(main_ref, construction_mgr):
		main = main_ref
		construction_manager = construction_mgr

func spawn_crew_member():
		var tile_pos = Vector2i(main.START_BASE_POS + main.START_BASE_SIZE/2, main.START_BASE_POS + main.START_BASE_SIZE/2)
		var spawn_world_pos = main.tilemap.map_to_local(tile_pos)

		var crew_instance = main.crew_scene.instantiate()
		main.add_child(crew_instance)
		crew_instance.add_to_group("crew")
		crew_instance.global_position = spawn_world_pos
		crew_instance.initialize(spawn_world_pos)
		print("Crew Agent spawned at world position: " + str(spawn_world_pos))

func handle_crew_commands(event, command_type: String):
		var world_click_pos = main.game_camera.get_canvas_transform().affine_inverse() * event.position
		var target_tile_pos = main.tilemap.local_to_map(world_click_pos)
		var target_world_pos = main.tilemap.map_to_local(target_tile_pos)

		if command_type == "select_place":
				if main.has_method("display_tile_info"):
						main.display_tile_info(world_click_pos)
				if main.is_building:
						construction_manager.handle_construction_placement(target_tile_pos, target_world_pos)
				else:
						_handle_selection(world_click_pos)
		elif command_type == "command_cancel":
				if main.is_building:
						construction_manager.set_build_mode(false, "")
				elif main.selected_crew:
						if GlobalUtils.is_tile_pressurized(main.tilemap, target_tile_pos, main.LAYER_FLOOR):
								var zone_type = main.zone_manager.get_zone_type(target_tile_pos)
								var crew_role = _get_selected_crew_role()
								if not main.zone_manager.is_job_allowed(zone_type, crew_role):
										var zone_name = main.zone_manager.get_zone_name(zone_type)
										print("Command rejected: %s zone is restricted." % zone_name)
										return
								main.selected_crew.set_destination(target_world_pos)
								main.selected_crew.set_selected(false)
								main.selected_crew = null
								print("Command received: Move to " + str(target_tile_pos))
						else:
								print("Command rejected: Cannot move to unpressurized tile.")

func _handle_selection(world_click_pos: Vector2):
		var new_selected_crew = null
		var selection_radius = main.TILE_SIZE / 2.0

		for child in main.get_tree().get_nodes_in_group("crew"):
				var distance = child.global_position.distance_to(world_click_pos)
				if distance < selection_radius:
						new_selected_crew = child
						break

		if main.selected_crew != new_selected_crew:
				if main.selected_crew:
						main.selected_crew.set_selected(false)
				main.selected_crew = new_selected_crew
				if main.selected_crew:
						main.selected_crew.set_selected(true)
						print("Crew Agent selected: " + main.selected_crew.name)
				else:
						print("No crew agent selected.")

func _get_selected_crew_role() -> String:
		if not main.selected_crew:
				return "generalist"
		if main.selected_crew.has_method("get_job_role"):
				return main.selected_crew.get_job_role()
		if main.selected_crew.has_meta("job_role"):
				return str(main.selected_crew.get_meta("job_role"))
		if "job_role" in main.selected_crew:
				return str(main.selected_crew.job_role)
		return "generalist"
