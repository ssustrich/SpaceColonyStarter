extends Node2D

const GameInitializer = preload("res://scripts/managers/game_initializer.gd")
const ResourceManager = preload("res://scripts/managers/resource_manager.gd")
const ConstructionManager = preload("res://scripts/managers/construction_manager.gd")
const CrewManager = preload("res://scripts/managers/crew_manager.gd")
const ZoneManager = preload("res://scripts/managers/zone_manager.gd")
const InputController = preload("res://scripts/managers/input_controller.gd")

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
var built_modules: Array = []
var selected_crew: CharacterBody2D = null
var zone_map: Dictionary = {}

const ZONE_TYPE_UNASSIGNED := ZoneManager.ZONE_TYPE_UNASSIGNED
const ZONE_TYPE_GENERAL := ZoneManager.ZONE_TYPE_GENERAL
const ZONE_TYPE_STORAGE := ZoneManager.ZONE_TYPE_STORAGE
const ZONE_TYPE_INDUSTRIAL := ZoneManager.ZONE_TYPE_INDUSTRIAL

## Construction State
var is_building: bool = false
var blueprint_type: String = ""
var is_hull_expanding: bool = false # H key mode

## Data
var MODULE_DATABASE: Dictionary = {}

## Node References (Must match node names in Game.tscn)
@onready var tilemap: TileMap = $TileMap
@onready var zone_overlay: TileMap = $ZoneOverlay
@onready var game_camera: Camera2D = $Camera2D
@onready var power_timer: Timer = $PowerTimer
@onready var crew_scene: PackedScene = preload("res://Crew.tscn")

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

        construction_manager = ConstructionManager.new(self)
        resource_manager = ResourceManager.new(self)
        crew_manager = CrewManager.new(self, construction_manager)
        zone_manager = ZoneManager.new(self, zone_overlay)
        input_controller = InputController.new(self, crew_manager, construction_manager, zone_manager)
        game_initializer = GameInitializer.new(self, construction_manager, zone_manager)

        zone_manager.initialize_zone_map()

        call_deferred("_initialize_game_systems")

func _initialize_game_systems():
        game_initializer.load_module_database()
        game_initializer.setup_starting_base()
        power_timer.start(5.0)
        resource_manager.calculate_power()
        zone_manager.refresh_overlay_from_map()
        # crew_manager.spawn_crew_member()

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
