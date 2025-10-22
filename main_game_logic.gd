extends Node2D

## Game State Constants
const GAME_NAME = "Void Keeper"
const TILE_SIZE = 64.0
const START_BASE_POS = 50 # Starting tile coordinate
const START_BASE_SIZE = 5 # Size of the initial pressurized block

## Layer Indexing (Must match TileSet layers in Godot Editor)
const LAYER_HULL = 0
const LAYER_FLOOR = 1
const LAYER_BLUEPRINT = 2

## Resources
var resources: Dictionary = {
	"metal": 100.0,
	"components": 50.0,
	"power": 0.0,
	"power_max_gen": 0.0,
	"power_max_cons": 0.0,
}

## Game State Variables
var built_modules: Array = [] # Stores: [{type: "floor", pos: Vector2i(x,y), tile_id: 0}, ...]
var selected_crew: CharacterBody2D = null

## Construction State
var is_building: bool = false
var blueprint_type: String = ""
var is_hull_expanding: bool = false # H key mode

## Data
var MODULE_DATABASE: Dictionary = {}

## Node References (Must match node names in Game.tscn)
@onready var tilemap: TileMap = $TileMap
@onready var game_camera: Camera2D = $Camera2D
@onready var power_timer: Timer = $PowerTimer
@onready var crew_scene: PackedScene = preload("res://Crew.tscn")

## Input Variables for Camera Drag
var is_middle_mouse_down: bool = false
var drag_start_position: Vector2 = Vector2.ZERO
const CAMERA_ZOOM_MIN = Vector2(0.5, 0.5)
const CAMERA_ZOOM_MAX = Vector2(2.0, 2.0)

# ==============================================================================
# 1. INITIALIZATION (CALLED DEFERRED)
# ==============================================================================

func _ready():
	# Use call_deferred to ensure all @onready variables (like tilemap) are initialized
	call_deferred("_initialize_game_systems")

func _initialize_game_systems():
	# Load external data
	_load_module_database()

	# Setup the initial base structure
	_setup_starting_base()

	# Start the power timer loop
	power_timer.start(5.0)

	# Calculate initial power and resources
	_calculate_power()
	
	# Spawn the first crew member
	#_spawn_crew_member()

func _load_module_database():
	var file = FileAccess.open("res://blocks/modules.json", FileAccess.READ)
	if FileAccess.get_open_error() == OK:
		var json_string = file.get_as_text()
		var json_data = JSON.parse_string(json_string)
		if json_data is Dictionary:
			
			# Convert JSON array coordinates [x, y] to Godot's Vector2i
			for type_key in json_data.keys():
				var module_data = json_data[type_key]
				if module_data.has("atlas_coords"):
					var coords_array = module_data.atlas_coords
					module_data.atlas_coords = Vector2i(coords_array[0], coords_array[1])
				MODULE_DATABASE[type_key] = module_data
			
			# Diagnostic check
			print(str(MODULE_DATABASE.keys().size()) + " modules loaded successfully from JSON.")
		else:
			push_error("Error parsing modules.json: Invalid JSON format.")
	else:
		push_error("Error opening modules.json: " + str(FileAccess.get_open_error()))


func _setup_starting_base():
	var center_pos = Vector2i(START_BASE_POS, START_BASE_POS)
	
	# Calculate world center position for camera focus
	var center_tile_pos = center_pos + Vector2i(START_BASE_SIZE/2, START_BASE_SIZE/2)
	var center_world_pos = tilemap.map_to_local(center_tile_pos)
	game_camera.global_position = center_world_pos
	
	var hull_data = MODULE_DATABASE["hull"]
	var floor_data = MODULE_DATABASE["floor"]
	var solar_data = MODULE_DATABASE["solar_collector"]
	
	# 1. Place HULL (Layer 0)
	for x in range(START_BASE_SIZE + 2):
		for y in range(START_BASE_SIZE + 2):
			var tile_pos = Vector2i(center_pos.x + x - 1, center_pos.y + y - 1)
			
			# Place hull around the perimeter
			if x == 0 or x == START_BASE_SIZE + 1 or y == 0 or y == START_BASE_SIZE + 1:
				_set_module_tile("hull", tile_pos)
			
	# 2. Place FLOOR and Starting Module (Layer 1)
	for x in range(START_BASE_SIZE):
		for y in range(START_BASE_SIZE):
			var tile_pos = Vector2i(center_pos.x + x, center_pos.y + y)
			
			# Place Floor tiles
			_set_module_tile("floor", tile_pos)
			
			# Place starting Solar Collector near the center
			if x == 2 and y == 0:
				_set_module_tile("solar_collector", tile_pos)
			
			if x == 1 and y == 0:
				_set_module_tile("void_drill", tile_pos)

func _set_module_tile(type: String, tile_pos: Vector2i):
	var data = MODULE_DATABASE.get(type)
	
	if not data:
		push_error("Attempted to place unknown module type: " + type)
		return
		
	# Set the TileMap cell
	GlobalUtils._set_layer_cell(tilemap, data.layer, tile_pos, data.atlas_coords)
	
	
	# Update built_modules array
	var existing_index = -1
	for i in range(built_modules.size()):
		if built_modules[i].pos == tile_pos:
			existing_index = i
			break
			
	var new_module = {
		"type": type,
		"pos": tile_pos,
		"layer": data.layer
	}
	
	if existing_index != -1:
		built_modules[existing_index] = new_module
	else:
		built_modules.append(new_module)

# ==============================================================================
# 2. GAME LOOPS AND RESOURCE MANAGEMENT
# ==============================================================================

func _on_power_timer_timeout():
	_calculate_power()
	_gather_resources()
	
func _calculate_power():
	resources.power_max_gen = 0.0
	resources.power_max_cons = 0.0

	for module in built_modules:
		var type_data = MODULE_DATABASE.get(module.type)
		
		# Safely retrieve the 'stats' dictionary, defaulting to empty if not found.
		var module_stats = type_data.get("stats", {}) 

		if module_stats:
			resources.power_max_gen += module_stats.get("power_gen", 0.0)
			resources.power_max_cons += module_stats.get("power_cons", 0.0)

	resources.power = resources.power_max_gen - resources.power_max_cons
	
	print("--- Power Balance: " + str(resources.power_max_gen) + " GEN - " + str(resources.power_max_cons) + " CONS = " + str(resources.power))

func _gather_resources():
	print(built_modules)
	for module in built_modules:
		var type_data = MODULE_DATABASE.get(module.type)
		var module_stats = type_data.get("stats", {}) 

		if module_stats.has("metal_rate"):
			var rate = module_stats.metal_rate
			if rate > 0 and resources.power > resources.power_max_cons: # Only gather if positive power balance
				resources.metal += rate
				print("Gathered " + str(rate) + " metal. Total metal: " + str(resources.metal))

# ==============================================================================
# 3. CREW MANAGEMENT AND MOVEMENT
# ==============================================================================

func _spawn_crew_member():
	var tile_pos = Vector2i(START_BASE_POS + START_BASE_SIZE/2, START_BASE_POS + START_BASE_SIZE/2)
	var spawn_world_pos = tilemap.map_to_local(tile_pos)

	var crew_instance = crew_scene.instantiate()
	add_child(crew_instance)
	
	# Must explicitly add to group for selection logic to work
	crew_instance.add_to_group("crew")
	
	crew_instance.global_position = spawn_world_pos
	crew_instance.initialize(spawn_world_pos)
	
	print("Crew Agent spawned at world position: " + str(spawn_world_pos))

# ==============================================================================
# 4. INPUT AND COMMAND HANDLING
# ==============================================================================

func _unhandled_input(event):
	# --- Camera Zoom (Mouse Wheel) ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.is_pressed():
			game_camera.zoom = game_camera.zoom * 1.1
			game_camera.zoom = game_camera.zoom.clamp(CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.is_pressed():
			game_camera.zoom = game_camera.zoom / 1.1
			game_camera.zoom = game_camera.zoom.clamp(CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
			get_viewport().set_input_as_handled()
			return
			
		# --- Middle Mouse Button Drag (Panning) ---
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			is_middle_mouse_down = event.is_pressed()
			if event.is_pressed():
				drag_start_position = event.position
				
		# --- Left Click (Selection/Placement) ---
		elif event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			_handle_crew_commands(event, "select_place")
			get_viewport().set_input_as_handled()
			return

		# --- Right Click (Command/Cancel) ---
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			_handle_crew_commands(event, "command_cancel")
			get_viewport().set_input_as_handled()
			return
			
	# --- Keyboard Input (Build Toggles) ---
	if event is InputEventKey:
		if not event.is_pressed(): return
		
		# B: Blueprint Mode
		if event.is_action_pressed("toggle_build"):
			_set_build_mode(not is_building, "floor")
			get_viewport().set_input_as_handled()
			return
			
		
		# H: Hull Expansion Mode
		if event.is_action_pressed("toggle_hull_expand"):
			_set_build_mode(not is_building, "hull_expand") # Hull expansion uses a special type
			get_viewport().set_input_as_handled()
			return

		# D: Drill Placement Mode
		if event.is_action_pressed("toggle_drill_place"):
			_set_build_mode(not is_building, "void_drill")
			get_viewport().set_input_as_handled()
			return

func _physics_process(delta):
	_handle_camera_movement(delta)
	
	if is_middle_mouse_down:
		_handle_camera_drag()

func _handle_camera_movement(delta):
	var move_speed = 500 * delta
	var direction = Vector2.ZERO
	
	# WASD or Arrow Keys (Standard UI actions)
	if Input.is_action_pressed("ui_right"): direction.x += 1
	if Input.is_action_pressed("ui_left"): direction.x -= 1
	if Input.is_action_pressed("ui_down"): direction.y += 1
	if Input.is_action_pressed("ui_up"): direction.y -= 1
	
	if direction.length() > 0:
		game_camera.global_position += direction.normalized() * move_speed

func _handle_camera_drag():
	var drag_delta = drag_start_position - get_viewport().get_mouse_position()
	# The camera's position must be offset by the drag amount scaled by the current zoom level
	game_camera.global_position += drag_delta * game_camera.zoom
	drag_start_position = get_viewport().get_mouse_position()

func _handle_crew_commands(event, command_type: String):
	# Convert mouse screen position to world coordinates
	var world_click_pos = game_camera.get_canvas_transform().affine_inverse() * event.position
	var target_tile_pos = tilemap.local_to_map(world_click_pos)
	var target_world_pos = tilemap.map_to_local(target_tile_pos)

	if command_type == "select_place":
		if is_building:
			_handle_construction_placement(target_tile_pos, target_world_pos)
		else:
			# --- SELECTION LOGIC (Proximity Check) ---
			var new_selected_crew = null
			var selection_radius = TILE_SIZE / 2.0
			
			# Iterate through all crew agents (must be in "crew" group)
			for child in get_tree().get_nodes_in_group("crew"):
				var distance = child.global_position.distance_to(world_click_pos)
				# print("Crew distance to click: " + str(distance)) # Diagnostic print
				if distance < selection_radius:
					new_selected_crew = child
					break
			
			# Update selection state
			if selected_crew != new_selected_crew:
				if selected_crew:
					selected_crew.set_selected(false)
				
				selected_crew = new_selected_crew
				
				if selected_crew:
					selected_crew.set_selected(true)
					print("Crew Agent selected: " + selected_crew.name)
				else:
					print("No crew agent selected.")

	elif command_type == "command_cancel":
		if is_building:
			# Right-click cancels build mode
			_set_build_mode(false, "")
		elif selected_crew:
			# --- MOVEMENT COMMAND (Right-Click) ---
			
			# 1. Hull Expansion Mode
			if is_building and blueprint_type == "hull_expand":
				_handle_hull_expansion(target_tile_pos)
				
			# 2. Standard Move Command (Only allowed on pressurized tiles)
			elif GlobalUtils.is_tile_pressurized(tilemap, target_tile_pos, LAYER_FLOOR):
				selected_crew.set_destination(target_world_pos)
				selected_crew.set_selected(false) # Deselect after command
				selected_crew = null
				print("Command received: Move to " + str(target_tile_pos))
			else:
				print("Command rejected: Cannot move to unpressurized tile.")
				
func _set_build_mode(active: bool, type: String):
	is_building = active
	blueprint_type = type
	is_hull_expanding = (type == "hull_expand")

	if active:
		print("Entering construction mode: Building " + type + ". Left-click to place, Right-click to cancel.")
	else:
		print("Exiting construction mode.")

# ==============================================================================
# 5. CONSTRUCTION LOGIC
# ==============================================================================

func _handle_construction_placement(target_tile_pos: Vector2i, target_world_pos: Vector2):
	var type_data = MODULE_DATABASE.get(blueprint_type)
	
	if not type_data:
		push_error("Cannot place blueprint: Unknown type " + blueprint_type)
		return
		
	var cost = type_data.get("cost", {})
	
	# 1. Resource Check
	for resource_name in cost.keys():
		if resources.get(resource_name, 0) < cost[resource_name]:
			print("Cannot place blueprint: Insufficient " + resource_name + " (" + str(cost[resource_name]) + " needed).")
			return
			
	# 2. Placement Validation Check
	var target_tile_type = GlobalUtils.get_tile_type(tilemap, target_tile_pos, LAYER_HULL)
	
	if type_data.get("place_on_hull", false):
		# Validation for Void Drill (Must be placed ON the hull)
		if target_tile_type != "hull":
			print("Cannot place " + blueprint_type + ": Must be placed on an existing Hull section.")
			return
		
		# Immediately remove hull tile since the drill takes its place
		tilemap.set_cell(LAYER_HULL, target_tile_pos, -1) # Remove the hull tile
	
	else: 
		# Validation for Floor/Reactor/Airlock (Must be placed on empty tile adjacent to floor)
		if target_tile_type != "":
			print("Cannot place blueprint: Tile is already occupied or reserved.")
			return
		if not GlobalUtils.is_adjacent_to_floor(tilemap, target_tile_pos, LAYER_FLOOR):
			print("Cannot place blueprint: Must be adjacent to an existing floor tile.")
			return

	# 3. Placement (Always on Blueprint Layer)
	GlobalUtils._set_layer_cell(tilemap, LAYER_BLUEPRINT, target_tile_pos, type_data.atlas_coords)
	
	# 4. Deduct Resources
	for resource_name in cost.keys():
		resources[resource_name] -= cost[resource_name]
	
	print("Blueprint placed for " + blueprint_type + " at " + str(target_tile_pos) + ". Metal remaining: " + str(resources.metal))

	# --- Crew Assignment Logic (Placeholder - Removed for now) ---
	# if selected_crew:
	#     selected_crew.set_task("build_" + blueprint_type, target_tile_pos, target_world_pos)
	# else:
	#     print("No crew selected. Manually assign crew to construction.")


func _handle_hull_expansion(target_tile_pos: Vector2i):
	var hull_data = MODULE_DATABASE["hull"]
	var floor_data = MODULE_DATABASE["floor"]
	
	var cost = floor_data.get("cost", {}) # Use floor cost for hull expansion
	
	# 1. Resource Check
	for resource_name in cost.keys():
		if resources.get(resource_name, 0) < cost[resource_name]:
			print("Cannot expand hull: Insufficient " + resource_name + " (" + str(cost[resource_name]) + " needed).")
			return
			
	# 2. Validation: Must click on an existing HULL block
	var target_tile_type = GlobalUtils.get_tile_type(tilemap, target_tile_pos, LAYER_HULL)
	if target_tile_type != "hull":
		print("Cannot expand hull: Must click on an existing gray hull block.")
		return

	# 3. Conversion (Instant)
	
	# a. Change existing HULL to FLOOR
	_set_module_tile("floor", target_tile_pos)
	
	# b. Expand HULL outwards to any adjacent empty tiles
	var neighbors = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]
	
	for offset in neighbors:
		var neighbor_pos = target_tile_pos + offset
		var neighbor_type = GlobalUtils.get_tile_type(tilemap, neighbor_pos, LAYER_HULL)
		
		# If neighbor is empty (void) or a different tile type, place new hull
		if neighbor_type == "":
			_set_module_tile("hull", neighbor_pos)
			
	# 4. Deduct Resources and print
	for resource_name in cost.keys():
		resources[resource_name] -= cost[resource_name]
	
	print("Hull expanded instantly at " + str(target_tile_pos) + ". Metal remaining: " + str(resources.metal))
	
	# 5. Exit Hull Expansion Mode
	_set_build_mode(false, "")
	
	
# Function called by Crew.gd when construction is complete
func finalize_construction(blueprint_type: String, tile_pos: Vector2i):
	var module_to_build = blueprint_type.trim_prefix("build_")
	
	# 1. Clear the Blueprint Tile
	tilemap.set_cell(LAYER_BLUEPRINT, tile_pos, -1)
	
	# 2. Place the Final Module
	_set_module_tile(module_to_build, tile_pos)
	
	print("Construction complete: " + module_to_build + " built at " + str(tile_pos))
	_calculate_power() # Recalculate power after a module is added
