extends Node2D

const GameInitializer = preload("res://scripts/managers/game_initializer.gd")
const ResourceManager = preload("res://scripts/managers/resource_manager.gd")
const ConstructionManager = preload("res://scripts/managers/construction_manager.gd")
const CrewManager = preload("res://scripts/managers/crew_manager.gd")
const ZoneManager = preload("res://scripts/managers/zone_manager.gd")
const InputController = preload("res://scripts/managers/input_controller.gd")

## Game State Constants
const GAME_NAME = "Void Keeper"
const TILE_SIZE = 16.0
#const TILE_WIDTH = 16
#const TILE_HEIGHT = 24
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
var built_modules: Array = []
var selected_crew: CharacterBody2D = null
var zone_map: Dictionary = {}

const ZONE_TYPE_UNASSIGNED := ZoneManager.ZONE_TYPE_UNASSIGNED
const ZONE_TYPE_GENERAL := ZoneManager.ZONE_TYPE_GENERAL
const ZONE_TYPE_STORAGE := ZoneManager.ZONE_TYPE_STORAGE
const ZONE_TYPE_INDUSTRIAL := ZoneManager.ZONE_TYPE_INDUSTRIAL
const ZONE_TYPE_UNPREASURIZED := ZoneManager.ZONE_TYPE_UNPREASURIZED


## Construction State
var is_building: bool = false
var blueprint_type: String = ""
var is_hull_expanding: bool = false # H key mode

## Data
var MODULE_DATABASE: Dictionary = {}
var MODULE_DATABASE_RLUT: Dictionary = {}

## Node References (Must match node names in Game.tscn)
@onready var tilemap: TileMap = $TileMap
@onready var zone_overlay: TileMap = $ZoneOverlay
@onready var game_camera: Camera2D = $Camera2D
@onready var power_timer: Timer = $PowerTimer
@onready var crew_scene: PackedScene = preload("res://Crew.tscn")
@onready var resource_information: Label = $UI/TileInfoPanel/VBoxContainer/ResourceLabel
@onready var tile_info_panel: PanelContainer = $UI/TileInfoPanel
@onready var tile_info_title: Label = $UI/TileInfoPanel/VBoxContainer/TitleLabel
@onready var tile_info_coordinates: Label = $UI/TileInfoPanel/VBoxContainer/CoordinatesLabel
@onready var tile_info_contents: Label = $UI/TileInfoPanel/VBoxContainer/ContentsLabel
@onready var tile_info_zone: Label = $UI/TileInfoPanel/VBoxContainer/ZoneLabel
@onready var tile_info_environment: Label = $UI/TileInfoPanel/VBoxContainer/EnvironmentLabel

## Input Variables for Camera Drag
var is_middle_mouse_down: bool = false
var drag_start_position: Vector2 = Vector2.ZERO
const CAMERA_ZOOM_MIN = Vector2(0.5, 0.5)
const CAMERA_ZOOM_MAX = Vector2(2.0, 2.0)

## Managers
var game_initializer: GameInitializer
var resource_manager: ResourceManager
var construction_manager: ConstructionManager
var crew_manager: CrewManager
var zone_manager: ZoneManager
var input_controller: InputController

# ==============================================================================
# 1. INITIALIZATION (CALLED DEFERRED)
# ==============================================================================

func _ready():
		# Ensure render order keeps exterior modules (Hull layer) visible above the floor.
		tilemap.set_layer_z_index(LAYER_FLOOR, 0)
		tilemap.set_layer_z_index(LAYER_HULL, 1)
		tilemap.set_layer_z_index(LAYER_BLUEPRINT, 2)
		zone_overlay.set_layer_z_index(0, 3)
		zone_overlay.clear()
		_reset_tile_info_panel()

		construction_manager = ConstructionManager.new(self)
		resource_manager = ResourceManager.new(self)
		crew_manager = CrewManager.new(self, construction_manager)
		zone_manager = ZoneManager.new(self, zone_overlay)
		input_controller = InputController.new(self, crew_manager, construction_manager, zone_manager)
		game_initializer = GameInitializer.new(self, construction_manager, zone_manager)
		zone_manager.initialize_zone_map()
		
		GlobalUtils.register_main(self)		
		call_deferred("_initialize_game_systems")

func _initialize_game_systems():
		game_initializer.load_module_database()
		game_initializer.setup_starting_base()
		power_timer.start(5.0)
		resource_manager.calculate_power()
		zone_manager.refresh_overlay_from_map()
		crew_manager.spawn_crew_member()

# ==============================================================================
# 2. GAME LOOPS AND RESOURCE MANAGEMENT
# ==============================================================================

func _on_power_timer_timeout():
		resource_manager.on_power_timer_timeout()

# ==============================================================================
# 3. CREW MANAGEMENT AND MOVEMENT
# ==============================================================================

# ==============================================================================
# 4. INPUT AND COMMAND HANDLING
# ==============================================================================

func _unhandled_input(event):
		input_controller.handle_unhandled_input(event)

func _physics_process(delta):
				input_controller.physics_process(delta)

# ==============================================================================
# 5. CONSTRUCTION LOGIC
# ==============================================================================

# Function called by Crew.gd when construction is complete
func finalize_construction(blueprint_type: String, tile_pos: Vector2i):
		construction_manager.finalize_construction(blueprint_type, tile_pos)

func get_zone_type_for_tile(tile_pos: Vector2i) -> String:
				return zone_manager.get_zone_type(tile_pos)

func display_tile_info(world_position: Vector2) -> void:
				if tilemap == null:
								return

				var tile_pos := tilemap.local_to_map(world_position)
				var zone_type := zone_manager.get_zone_type(tile_pos)
				var zone_name := zone_manager.get_zone_name(zone_type)
				var contents_description := _describe_tile_contents(tile_pos)
				var pressurized := GlobalUtils.is_tile_pressurized(tilemap, tile_pos, LAYER_FLOOR)
				var job_filters: Array = zone_manager.get_zone_definition(zone_type).get("job_filters", [])
				var zone_details := zone_name
				if not job_filters.is_empty():
								zone_details += " (Jobs: " + ", ".join(job_filters) + ")"

				tile_info_panel.visible = true
				
				#print("--- Power Balance: " + str(main.resources.power_max_gen) + " GEN - " + str(main.resources.power_max_cons) + " CONS = " + str(main.resources.power))
				
				#resource_information.text = "Reources Balance: %s metal\n Power Produced: %s \n Power: %s" % [resources["metal"] ,  resources["components"], resources["power"], resources["power_max_gen"], resources["power_max_cons"]]
				tile_info_title.text = "Tile Stats"
				resource_information.text = "Reources Balance\n: Metal:  %s\n Components: %s \n Power: %s \n Power Capacity: %s \n Power Consumed: %s" % [resources["metal"] ,  resources["components"], resources["power"], resources["power_max_gen"], resources["power_max_cons"]]
				tile_info_coordinates.text = "Coordinates: %d, %d" % [tile_pos.x, tile_pos.y]
				tile_info_contents.text = "Contents: " + contents_description
				tile_info_zone.text = "Zone: " + zone_details
				tile_info_environment.text = "Pressurized: " + ("Yes" if pressurized else "No")

func _reset_tile_info_panel() -> void:
				if tile_info_panel == null:
								return
				tile_info_panel.visible = false
				tile_info_title.text = "Tile Stats"
				tile_info_coordinates.text = "Click a tile to inspect it."
				tile_info_contents.text = ""
				tile_info_zone.text = ""
				tile_info_environment.text = ""

func _describe_tile_contents(tile_pos: Vector2i) -> String:
				var layers := [
								{"layer": LAYER_BLUEPRINT, "prefix": "Blueprint: "},
								{"layer": LAYER_FLOOR, "prefix": ""},
								{"layer": LAYER_HULL, "prefix": ""},
				]

				var descriptions: Array[String] = []
				for entry in layers:
								var raw_type := GlobalUtils.get_tile_type(tilemap, tile_pos, entry.layer)
								if raw_type == "":
												continue
								var formatted := _format_module_name(raw_type)
								if formatted == "":
												continue
								var prefix: String = entry.prefix
								if prefix != "" and not formatted.begins_with(prefix):
												descriptions.append(prefix + formatted)
								else:
												descriptions.append(formatted)

				if descriptions.is_empty():
								return "Empty space"

				return ", ".join(descriptions)

func _format_module_name(raw_name: String) -> String:
				if raw_name == "":
								return ""

				var base_name := raw_name
				var variant := ""

				if ":" in raw_name:
								var parts := raw_name.split(":", false, 2)
								base_name = parts[0]
								variant = parts[1] if parts.size() > 1 else ""

				var formatted_base := _to_title(base_name)
				if variant == "":
								return formatted_base
				return formatted_base + " (" + _to_title(variant) + ")"

func _to_title(value: String) -> String:
				var words := value.replace("_", " ").split(" ", false)
				for i in range(words.size()):
								if words[i].length() == 0:
												continue
								words[i] = words[i].substr(0, 1).to_upper() + words[i].substr(1).to_lower()
				return " ".join(words)
