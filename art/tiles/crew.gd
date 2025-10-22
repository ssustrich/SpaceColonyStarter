extends Node

# Void Keeper - Main Game Logic
# This script manages initialization, input, game state, and core loops.

## --- CONSTANTS ---
const START_BASE_POS = 50  # Starting tile position (x, y) for the base center on the grid
const START_BASE_SIZE = 5  # Size of the initial pressurized block (e.g., 5x5)
const TILE_SIZE = 64       # Assumed size of a single tile in pixels (for world calculation)

## --- RESOURCE TRACKING ---
const STARTING_RESOURCES: Dictionary = {
	"metal": 100,
	"components": 50,
	"power": 0.0,
	"power_max_gen": 0.0,
	"power_max_cons": 0.0,
}

## --- PATHS ---
const CREW_SCENE_PATH = "res://Crew.tscn"
const MODULE_DB_PATH = "res://blocks/modules.json"

## --- LAYERS ---
const LAYER_HULL = 0
const LAYER_FLOOR = 1
const LAYER_BLUEPRINT = 2

## --- GAME STATE VARS ---
var resources: Dictionary = STARTING_RESOURCES.duplicate()
var built_modules: Array = [] # Stores: [{type: "hull", tile_pos: Vector2i(x, y)}, ...]
var MODULE_DATABASE: Dictionary = {}

## --- INPUT/SELECTION VARS ---
var is_building: bool = false
var build_mode: String = "" # e.g., "floor", "hull_expand", "void_drill", "reactor"
var is_middle_mouse_down: bool = false
var selected_crew: CharacterBody2D = null

## --- NODES ---
@onready var tilemap = $TileMap
@onready var game_camera = $Camera2D
@onready var power_timer = $PowerTimer
@onready var crew_scene = load(CREW_SCENE_PATH)


# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready():
	# Deferred call ensures all @onready vars (like tilemap and power_timer) are initialized
	call_deferred("_initialize_game_systems")

func _initialize_game_systems():
	if not _load_module_database():
		print("FATAL ERROR: Failed to load MODULE DATABASE.")
		get_tree().quit()
		return

	_setup_starting_base()
	_calculate_power() # Run once on startup
	power_timer.wait_time = 5.0
	power_timer.start()

	#_spawn_crew_member()
	print("Game systems initialized and running.")


func _load_module_database() -> bool:
	var file = FileAccess.open(MODULE_DB_PATH, FileAccess.READ)
	if FileAccess.get_open_error() != OK:
		print("Error opening module database JSON: ", FileAccess.get_open_error())
		return false

	var content = file.get_as_text()
	var json_data = JSON.parse_string(content)

	if json_data is Dictionary:
		# Convert JSON arrays [x, y] to Godot's Vector2i
		for type_name in json_data:
			var data = json_data[type_name]
			# Convert atlas_coords [x, y] array to Vector2i
			if data.has("atlas_coords") and data.atlas_coords is Array:
				data.atlas_coords = Vector2i(data.atlas_coords[0], data.atlas_coords[1])
			MODULE_DATABASE[type_name] = data
		return true

	#print("Error parsing module database JSON: ", JSON.get_error_message())
	return false


func _setup_starting_base():
	var center_tile_x = START_BASE_POS + START_BASE_SIZE / 2
	var center_tile_y = START_BASE_POS + START_BASE_SIZE / 2
	
	# 1. Place the initial tiles (Hull and Floor)
	for x in range(START_BASE_POS, START_BASE_POS + START_BASE_SIZE + 1):
		for y in range(START_BASE_POS, START_BASE_POS + START_BASE_SIZE + 1):
			var tile_pos = Vector2i(x, y)
			
			# Place Hull around the perimeter
			if x == START_BASE_POS || x == START_BASE_POS + START_BASE_SIZE || \
			   y == START_BASE_POS || y == START_BASE_POS + START_BASE_SIZE:
				
				var hull_data = MODULE_DATABASE["hull"]
				var hull_coords = hull_data.atlas_coords
				
				GlobalUtils._set_layer_cell(tilemap, LAYER_HULL, tile_pos, hull_coords)
				built_modules.append({"type": "hull", "tile_pos": tile_pos})
			
			# Place Floor inside
			else:
				var floor_data = MODULE_DATABASE["floor"]
				var floor_coords = floor_data.atlas_coords
				
				GlobalUtils._set_layer_cell(tilemap, LAYER_FLOOR, tile_pos, floor_coords)
				built_modules.append({"type": "floor", "tile_pos": tile_pos})
	
	# 2. Place the starting Solar Collector
	var solar_data = MODULE_DATABASE["solar_collector"]
	var solar_coords = solar_data.atlas_coords
	var solar_pos = Vector2i(START_BASE_POS + 1, START_BASE_POS + 1)
	
	GlobalUtils._set_layer_cell(tilemap, LAYER_FLOOR, solar_pos, solar_coords)
	built_modules.append({"type": "solar_collector", "tile_pos": solar_pos})
	
	# 3. Position the Camera
	var center_tile_pos = Vector2i(center_tile_x, center_tile_y)
	var center_world_pos = tilemap.map_to_local(center_tile_pos)
	game_camera.global_position = center_world_pos
	
	print("Initial base setup complete.")


func _spawn_crew_member():
	var crew_instance = crew_scene.instantiate()
	add_child(crew_instance)

	# Find a floor tile for spawning (center tile)
	var spawn_tile_pos = Vector2i(START_BASE_POS + START_BASE_SIZE / 2, START_BASE_POS + START_BASE_SIZE / 2)
	var spawn_world_pos = tilemap.map_to_local(spawn_tile_pos)

	crew_instance.global_position = spawn_world_pos
	crew_instance.initialize(spawn_world_pos)
	crew_instance.add_to_group("crew")
	
	print("Crew Agent spawned at world position: ", spawn_world_pos)


# ==============================================================================
# GAME LOOP FUNCTIONS (TIMERS)
# ==============================================================================

func _on_power_timer_timeout():
	_calculate_power()
	_gather_resources()
	
	print("--- New Tick ---")
	print("Current Resources: ", resources)


func _calculate_power():
	resources.power_max_gen = 0.0
	resources.power_max_cons = 0.0

	for module in built_modules:
		var type_data = MODULE_DATABASE.get(module.type)
		
		# Safely get the 'stats' dictionary, defaulting to an empty dictionary if not found.
		var module_stats = type_data.get("stats", {}) 

		if module_stats:
			resources.power_max_gen += module_stats.get("power_gen", 0.0)
			resources.power_max_cons += module_stats.get("power_cons", 0.0)

	resources.power = resources.power_max_gen - resources.power_max_cons

	if resources.power < 0:
		# Emergency: Base systems are failing!
		print("CRITICAL POWER SHORTAGE: Systems operating at reduced capacity.")
	
	print("--- Power Balance: %.1f GEN - %.1f CONS = %.1f" % [resources.power_max_gen, resources.power_max_cons, resources.power])


func _gather_resources():
	if resources.power < 0:
		print("Cannot gather resources due to power shortage.")
		return

	for module in built_modules:
		var type_data = MODULE_DATABASE.get(module.type)
		var module_stats = type_data.get("stats", {})

		if module_stats:
			var metal_rate = module_stats.get("metal_rate", 0)
			
			if metal_rate > 0:
				resources.metal += metal_rate
				print("Gathered %d metal from %s." % [metal_rate, module.type])


# ==============================================================================
# INPUT AND COMMANDS
# ==============================================================================

func _unhandled_input(event):
	_handle_camera_movement(event)
	
	# Handle key presses (B, H, D)
	if event.is_action_pressed("toggle_build"):
		# Toggle Floor Blueprint Mode (Crew Required)
		_set_build_mode(not is_building, "floor")
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_hull_expand"):
		# Toggle Hull Expansion Mode (Instant)
		_set_build_mode(not is_building, "hull_expand")
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_drill_place"):
		# Toggle Void Drill Placement (Instant)
		_set_build_mode(not is_building, "void_drill")
		get_viewport().set_input_as_handled()
		return
	
	# Handle mouse input
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_middle_mouse_down = event.pressed
			get_viewport().set_input_as_handled()
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			game_camera.zoom = game_camera.zoom * 1.1
			game_camera.zoom = game_camera.zoom.clamp(Vector2(0.5, 0.5), Vector2(2.0, 2.0))
			get_viewport().set_input_as_handled()

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			game_camera.zoom = game_camera.zoom / 1.1
			game_camera.zoom = game_camera.zoom.clamp(Vector2(0.5, 0.5), Vector2(2.0, 2.0))
			get_viewport().set_input_as_handled()
			
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_left_click(event)
			get_viewport().set_input_as_handled()
		
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click(event)
			get_viewport().set_input_as_handled()


func _handle_camera_movement(event):
	var pan_speed = 5.0 / game_camera.zoom.x
	var move_dir = Vector2.ZERO

	# WASD/Arrow Panning
	if Input.is_action_pressed("ui_right"): move_dir.x += 1
	if Input.is_action_pressed("ui_left"): move_dir.x -= 1
	if Input.is_action_pressed("ui_down"): move_dir.y += 1
	if Input.is_action_pressed("ui_up"): move_dir.y -= 1
	
	if move_dir != Vector2.ZERO:
		game_camera.global_position += move_dir.normalized() * pan_speed
		return

	# Middle Mouse Drag Panning
	if event is InputEventMouseMotion and is_middle_mouse_down:
		game_camera.global_position -= event.relative * pan_speed
		get_viewport().set_input_as_handled()


func _handle_left_click(event):
	var world_click_pos = game_camera.get_canvas_transform().affine_inverse() * event.position
	var target_tile_pos = tilemap.local_to_map(world_click_pos)
	
	# 1. Handle Blueprint Placement
	if is_building:
		_handle_construction_placement(target_tile_pos)
		return
		
	# 2. Handle Crew Selection (Proximity Check)
	var max_dist = TILE_SIZE / 2 * game_camera.zoom.x # Effective radius based on zoom
	var found_crew = null
	
	for crew_agent in get_tree().get_nodes_in_group("crew"):
		var dist = crew_agent.global_position.distance_to(world_click_pos)
		print("Crew distance to click: ", dist)
		
		if dist < max_dist:
			found_crew = crew_agent
			break
			
	# Update selection state
	if selected_crew:
		selected_crew.set_selected(false)
		selected_crew = null
		
	if found_crew:
		selected_crew = found_crew
		selected_crew.set_selected(true)


func _handle_right_click(event):
	# Right-click cancels build mode or issues crew command
	if is_building:
		_set_build_mode(false, "")
		return
	
	var world_click_pos = game_camera.get_canvas_transform().affine_inverse() * event.position
	var target_tile_pos = tilemap.local_to_map(world_click_pos)
	var target_world_pos = tilemap.map_to_local(target_tile_pos)

	# 1. Issue Crew Movement Command
	if selected_crew:
		# Safety Check: Cannot move into unpressurized areas for standard move commands
		if not GlobalUtils.is_tile_pressurized(tilemap, target_tile_pos, LAYER_FLOOR):
			print("Command rejected: Tile is unpressurized (void or hull).")
			return
			
		selected_crew.set_task("move", target_tile_pos, target_world_pos)
		print("Command received: Move to ", target_tile_pos)


# ==============================================================================
# CONSTRUCTION LOGIC
# ==============================================================================

func _set_build_mode(enable: bool, type: String):
	is_building = enable
	build_mode = type
	
	if is_building:
		print("Entering construction mode: Building %s. Left-click to place, Right-click to cancel." % type)
	else:
		print("Exiting construction mode.")


func _handle_construction_placement(target_tile_pos: Vector2i):
	var module_data = MODULE_DATABASE.get(build_mode)
	var cost = module_data.get("cost", {})
	var task = module_data.get("task", "")
	
	# 1. Resource Check
	for resource_name in cost:
		if resources.get(resource_name, 0) < cost[resource_name]:
			print("Cannot place blueprint: Insufficient %s (%d needed)." % [resource_name, cost[resource_name]])
			return
			
	# 2. Placement Validation (Type-Specific)
	var existing_tile_type = GlobalUtils.get_tile_type(tilemap, target_tile_pos, LAYER_HULL)
	var existing_floor_type = GlobalUtils.get_tile_type(tilemap, target_tile_pos, LAYER_FLOOR)
	
	var is_valid_placement = false
	
	if build_mode == "hull_expand":
		# Hull expansion must be placed on the Void, and adjacent to Floor
		if existing_tile_type == "" && existing_floor_type == "" && GlobalUtils.is_adjacent_to_floor(tilemap, target_tile_pos, LAYER_FLOOR):
			is_valid_placement = true
	elif build_mode == "void_drill":
		# Void Drill must be placed directly ON an existing hull block
		if existing_tile_type == "hull" && existing_floor_type == "":
			is_valid_placement = true
	elif task == "build_floor":
		# Floor must be placed on Void, adjacent to Floor, and not on another blueprint
		if existing_tile_type == "" && existing_floor_type == "" && GlobalUtils.is_adjacent_to_floor(tilemap, target_tile_pos, LAYER_FLOOR) && tilemap.get_cell_source_id(LAYER_BLUEPRINT, target_tile_pos) == -1:
			is_valid_placement = true
	else:
		# Default for other modules (e.g., Reactor) - placed on existing Floor
		if existing_floor_type == "floor" && tilemap.get_cell_source_id(LAYER_BLUEPRINT, target_tile_pos) == -1:
			is_valid_placement = true

	if not is_valid_placement:
		print("Cannot place blueprint: Invalid location for %s." % build_mode)
		return

	# 3. Deduct Resources (Instant for all modes at this step)
	for resource_name in cost:
		resources[resource_name] -= cost[resource_name]
		
	print("Resources deducted: ", cost)

	# 4. Execute Placement (Instant vs. Blueprint)
	
	if build_mode == "hull_expand":
		# INSTANT ACTION 1: Hull Expansion (Expands pressurized zone)
		
		# Place new floor tile (pressurized)
		_place_final_module("floor", target_tile_pos)
		
		# Check and expand the hull boundary around the new floor
		var neighbors: Array[Vector2i] = [
			Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)
		]
		
		for offset in neighbors:
			var neighbor_pos = target_tile_pos + offset
			if GlobalUtils.get_tile_type(tilemap, neighbor_pos, LAYER_HULL) == "":
				# Place new hull tile
				_place_final_module("hull", neighbor_pos)
		
		print("Hull successfully expanded.")
		_set_build_mode(false, "") # Exit build mode
		
	elif build_mode == "void_drill":
		# INSTANT ACTION 2: Void Drill Placement (Replaces Hull)
		
		# Clear the hull tile that was there
		GlobalUtils._set_layer_cell(tilemap, LAYER_HULL, target_tile_pos, Vector2i(-1, -1))
		
		# Mark the space under the drill as pressurized (Floor)
		_place_final_module("floor", target_tile_pos)
		
		# Place the final drill module tile
		_place_final_module("void_drill", target_tile_pos)
		
		# Remove the old hull entry from built_modules (IMPORTANT!)
		for i in range(built_modules.size()):
			if built_modules[i].tile_pos == target_tile_pos and built_modules[i].type == "hull":
				built_modules.remove_at(i)
				break
				
		print("Void Drill successfully placed (instant construction).")
		_set_build_mode(false, "") # Exit build mode
		
	else:
		# BLUEPRINT ACTION: Place the blueprint tile (Crew required to build)
		var blueprint_coords = module_data.atlas_coords
		GlobalUtils._set_layer_cell(tilemap, LAYER_BLUEPRINT, target_tile_pos, blueprint_coords)
		
		print("Blueprint placed for %s at %s. Metal remaining: %d" % [build_mode, target_tile_pos, resources.metal])
		
		# Crew Assignment Logic (Currently disabled as per user request)
		# if selected_crew:
		#     selected_crew.set_task(task, target_tile_pos, tilemap.map_to_local(target_tile_pos))


func _place_final_module(module_type: String, tile_pos: Vector2i):
	var module_data = MODULE_DATABASE.get(module_type)
	var layer = module_data.layer
	var atlas_coords = module_data.atlas_coords

	# Place the actual final module tile
	GlobalUtils._set_layer_cell(tilemap, layer, tile_pos, atlas_coords)
	
	# Add the final module to the tracking list
	built_modules.append({"type": module_type, "tile_pos": tile_pos})
	
	print("Placed final module: %s at %s" % [module_type, tile_pos])
	
	# Remove any blueprint tile at this location (if one was there)
	GlobalUtils._set_layer_cell(tilemap, LAYER_BLUEPRINT, tile_pos, Vector2i(-1, -1))


# This function would be called by the crew agent when construction is complete.
func finalize_construction(build_type: String, tile_pos: Vector2i):
	# This function is used when construction is done by crew (not instant build).
	print("Finalizing construction for %s at %s." % [build_type, tile_pos])
	
	# The build_type should be the name of the module, e.g., "floor"
	_place_final_module(build_type, tile_pos)
	
	# Note: Resources were already deducted when the blueprint was placed.
