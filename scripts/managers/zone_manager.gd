class_name ZoneManager
extends RefCounted

const ZONE_DATA_PATH := "res://blocks/zones.json"
const CLEAR_ATLAS := Vector3i(0, -1, -1)
const DEFAULT_OPACITY := 0.35

const ZONE_TYPE_UNASSIGNED := "unassigned"
const ZONE_TYPE_GENERAL := "general"
const ZONE_TYPE_STORAGE := "storage"
const ZONE_TYPE_INDUSTRIAL := "industrial"
const ZONE_TYPE_UNPREASURIZED := "unpreasurized"

const MODULE_CATEGORIES := {
	"airlock": "structure",
	"floor": "habitat",
	"hull": "structure",
	"reactor": "power",
	"solar_collector": "power",
	"void_drill": "industry",
}

const DEFAULT_ZONE_BY_CATEGORY := {
	"structure": ZONE_TYPE_UNASSIGNED,
	"habitat": ZONE_TYPE_GENERAL,
	"general": ZONE_TYPE_GENERAL,
	"industry": ZONE_TYPE_INDUSTRIAL,
	"power": ZONE_TYPE_INDUSTRIAL,
	"storage": ZONE_TYPE_STORAGE,
	"airlock": ZONE_TYPE_UNPREASURIZED,
}

var main: Node2D
var overlay: TileMap
var active_zone_type: String = ZONE_TYPE_UNASSIGNED

var zone_database: Dictionary = {}
var zone_types: Array[String] = []

var _zone_mode_active: bool = false
var _is_dragging: bool = false
var _painted_tiles: Dictionary = {}

func _init(main_ref: Node2D, overlay_map: TileMap) -> void:
	main = main_ref
	overlay = overlay_map
	_load_zone_database()
	_configure_overlay_map()

func _configure_overlay_map() -> void:
	if overlay == null:
		return
	overlay.clear()
	overlay.set_layer_z_index(0, 3)
	overlay.set_layer_modulate(0, Color(1, 1, 1, 1))

func _load_zone_database() -> void:
	zone_database.clear()
	zone_types.clear()

	var file := FileAccess.open(ZONE_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Unable to open zones database: %s" % ZONE_DATA_PATH)
		_load_default_zone_definitions()
		return

	var parsed_variant: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed_variant is Dictionary):
		push_error("zones.json has invalid format; expected a dictionary of zone entries.")
		_load_default_zone_definitions()
		return

	var parsed: Dictionary = parsed_variant

	for zone_id in parsed.keys():
		var raw_entry_variant: Variant = parsed[zone_id]
		if not (raw_entry_variant is Dictionary):
			continue

		var raw_entry: Dictionary = raw_entry_variant
		var entry: Dictionary = raw_entry.duplicate(true)
		entry["display_name"] = String(entry.get("display_name", zone_id.capitalize()))
		entry["allowed_categories"] = entry.get("allowed_categories", [])
		entry["job_filters"] = entry.get("job_filters", [])
		entry["opacity"] = clamp(float(entry.get("opacity", DEFAULT_OPACITY)), 0.0, 1.0)
		entry["layer"] = int(entry.get("layer", 0))
		entry["atlas_coords"] = _convert_atlas(entry.get("atlas_coords", CLEAR_ATLAS))
		entry["color"] = _parse_color(entry.get("color", null), entry["opacity"])

		zone_database[zone_id] = entry
		zone_types.append(zone_id)

	if not zone_database.has(ZONE_TYPE_UNASSIGNED):
		zone_database[ZONE_TYPE_UNASSIGNED] = {
			"display_name": "Unassigned",
			"atlas_coords": CLEAR_ATLAS,
			"opacity": 0.0,
			"allowed_categories": ["structure"],
			"job_filters": [],
			"layer": 0,
			"color": Color(1, 1, 1, 0.0),
		}
		zone_types.append(ZONE_TYPE_UNASSIGNED)

func _load_default_zone_definitions() -> void:
	zone_database = {
		ZONE_TYPE_UNASSIGNED: {
			"display_name": "Unassigned",
			"atlas_coords": CLEAR_ATLAS,
			"opacity": 0.0,
			"allowed_categories": ["structure"],
			"job_filters": [],
			"layer": 0,
			"color": Color(1, 1, 1, 0.0),
		},
		ZONE_TYPE_GENERAL: {
			"display_name": "Habitation",
			"atlas_coords": Vector3i(2, 0, 0),
			"opacity": DEFAULT_OPACITY,
			"allowed_categories": ["general", "habitat", "structure"],
			"job_filters": [],
			"layer": 0,
			"color": Color(1, 1, 1, DEFAULT_OPACITY),
		},
		ZONE_TYPE_STORAGE: {
			"display_name": "Logistics",
			"atlas_coords": Vector3i(2, 1, 0),
			"opacity": DEFAULT_OPACITY,
			"allowed_categories": ["storage", "structure"],
			"job_filters": ["generalist", "quartermaster"],
			"layer": 0,
			"color": Color(1, 1, 1, DEFAULT_OPACITY),
		},
		ZONE_TYPE_INDUSTRIAL: {
			"display_name": "Industrial",
			"atlas_coords": Vector3i(2, 2, 0),
			"opacity": DEFAULT_OPACITY,
			"allowed_categories": ["industry", "power", "structure"],
			"job_filters": ["generalist", "engineer"],
			"layer": 0,
			"color": Color(1, 1, 1, DEFAULT_OPACITY),
		},
		ZONE_TYPE_UNPREASURIZED: {
			"display_name": "Unsafe",
			"atlas_coords": Vector3i(3, 7, 7),
			"opacity": DEFAULT_OPACITY,
			"allowed_categories": ["airlock"],
			"job_filters": ["generalist", "engineer"],
			"layer": 0,
			"color": Color(1, 1, 1, DEFAULT_OPACITY),
			
			
		}
	}
	zone_types = zone_database.keys()

func _convert_atlas(value) -> Vector3i:
	if value is Vector3i:
		return value
	if value is Array and value.size() >= 3:
		return Vector3i(int(value[0]), int(value[1]), int(value[2]))
	return CLEAR_ATLAS

func _parse_color(value, opacity: float) -> Color:
	var color := Color(1, 1, 1, opacity)
	if value == null:
		return color
	if value is Color:
		color = value
	elif value is String:
		color = Color(value)
	elif value is Array and value.size() >= 3:
		var r := float(value[0])
		var g := float(value[1])
		var b := float(value[2])
		var a := opacity
		if value.size() >= 4:
			a = float(value[3])
		color = Color(r, g, b, a)
	color.a = clamp(color.a, 0.0, 1.0)
	if opacity >= 0.0:
		color.a = clamp(opacity if value == null or (value is Array and value.size() < 4) else color.a, 0.0, 1.0)
	return color

func initialize_zone_map() -> void:
	main.zone_map.clear()
	if overlay:
		overlay.clear()

func ensure_zone(tile_pos: Vector2i, default_zone: String = ZONE_TYPE_GENERAL) -> void:
	if not main.zone_map.has(tile_pos):
		main.zone_map[tile_pos] = default_zone
		_update_overlay(tile_pos, default_zone)
	else:
		_update_overlay(tile_pos, main.zone_map[tile_pos])

func set_zone(tile_pos: Vector2i, zone_type: String) -> void:
	if not zone_database.has(zone_type):
		zone_type = ZONE_TYPE_UNASSIGNED
	main.zone_map[tile_pos] = zone_type
	_update_overlay(tile_pos, zone_type)

func refresh_overlay_from_map() -> void:
	if not overlay:
		return
	overlay.clear()
	for tile_pos in main.zone_map.keys():
		_update_overlay(tile_pos, main.zone_map[tile_pos])

func start_zone_mode(zone_type: String) -> void:
	if not zone_database.has(zone_type):
		zone_type = ZONE_TYPE_UNASSIGNED
	active_zone_type = zone_type
	_zone_mode_active = true
	_painted_tiles.clear()
	var mode_name = get_zone_name(active_zone_type)
	if active_zone_type == ZONE_TYPE_UNASSIGNED:
		print("Zone paint mode: Clearing assignments. Left-click and drag to erase, Right-click to cancel.")
	else:
		print("Zone paint mode: %s. Left-click and drag to paint, Right-click to cancel." % mode_name)

func cancel_zone_mode() -> void:
	var was_active = _zone_mode_active or _is_dragging
	_zone_mode_active = false
	_is_dragging = false
	_painted_tiles.clear()
	active_zone_type = ZONE_TYPE_UNASSIGNED
	if was_active:
		print("Zone paint mode canceled.")

func is_zone_mode_active() -> bool:
	return _zone_mode_active

func begin_paint(world_position: Vector2) -> void:
	if not _zone_mode_active:
		return
	_is_dragging = true
	_apply_zone(world_position)

func continue_paint(world_position: Vector2) -> void:
	if not _zone_mode_active or not _is_dragging:
		return
	_apply_zone(world_position)

func end_paint() -> void:
	_is_dragging = false
	_painted_tiles.clear()

func get_zone_type(tile_pos: Vector2i) -> String:
	return main.zone_map.get(tile_pos, ZONE_TYPE_UNASSIGNED)

func get_zone_definition(zone_type: String) -> Dictionary:
	return zone_database.get(zone_type, zone_database.get(ZONE_TYPE_UNASSIGNED, {}))

func get_zone_info_for_tile(tile_pos: Vector2i) -> Dictionary:
	var zone_type = get_zone_type(tile_pos)
	return get_zone_definition(zone_type)

func get_zone_name(zone_type: String) -> String:
	return String(get_zone_definition(zone_type).get("display_name", zone_type.capitalize()))

func get_zone_types() -> Array:
	return zone_types.duplicate()

func get_module_category(module_type: String) -> String:
	return MODULE_CATEGORIES.get(module_type, "general")

func get_default_zone_for_category(category: String) -> String:
	return DEFAULT_ZONE_BY_CATEGORY.get(category, ZONE_TYPE_GENERAL)

func is_category_allowed(zone_type: String, category: String) -> bool:
	var allowed: Array = get_zone_definition(zone_type).get("allowed_categories", [])
	if allowed.is_empty():
		return true
	return allowed.has(category)

func is_job_allowed(zone_type: String, job_role: String) -> bool:
	var filters: Array = get_zone_definition(zone_type).get("job_filters", [])
	if filters.is_empty():
		return true
	return filters.has(job_role)

func _apply_zone(world_position: Vector2) -> void:
	var tile_pos = main.tilemap.local_to_map(world_position)
	if _painted_tiles.has(tile_pos):
		return
	_painted_tiles[tile_pos] = true
	set_zone(tile_pos, active_zone_type)

func _update_overlay(tile_pos: Vector2i, zone_type: String) -> void:
	if overlay == null:
		return

	var zone_data := get_zone_definition(zone_type)
	var layer := int(zone_data.get("layer", 0))
	var atlas: Vector3i = zone_data.get("atlas_coords", CLEAR_ATLAS)
	GlobalUtils._set_layer_cell_w_atlas(overlay, layer, tile_pos, atlas)
	_apply_tile_modulate(layer, tile_pos, zone_data)

func _apply_tile_modulate(layer: int, tile_pos: Vector2i, zone_data: Dictionary) -> void:
	if overlay == null:
		return
	var tile_data := overlay.get_cell_tile_data(layer, tile_pos)
	if tile_data == null:
		return
	var opacity: Variant = clamp(float(zone_data.get("opacity", DEFAULT_OPACITY)), 0.0, 1.0)
	var color_value = zone_data.get("color", Color(1, 1, 1, opacity))
	var color: Color = color_value if color_value is Color else Color(1, 1, 1, opacity)
	color.a = opacity if opacity >= 0.0 else color.a
	tile_data.set_modulate(color)
	# In Godot 4, modifying the TileData returned from get_cell_tile_data updates the map in place.
