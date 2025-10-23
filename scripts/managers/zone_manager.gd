class_name ZoneManager
extends RefCounted

const ZONE_TYPE_UNASSIGNED := "unassigned"
const ZONE_TYPE_GENERAL := "general"
const ZONE_TYPE_STORAGE := "storage"
const ZONE_TYPE_INDUSTRIAL := "industrial"

const ZONE_TYPES := [
        ZONE_TYPE_UNASSIGNED,
        ZONE_TYPE_GENERAL,
        ZONE_TYPE_STORAGE,
        ZONE_TYPE_INDUSTRIAL,
]

const ZONE_DEFINITIONS := {
        ZONE_TYPE_UNASSIGNED: {
                "display_name": "Unassigned",
                "color": Color(0.0, 0.0, 0.0, 0.0),
                "allowed_categories": ["structure"],
                "job_filters": [],
        },
        ZONE_TYPE_GENERAL: {
                "display_name": "Habitation",
                "color": Color(0.2, 0.6, 1.0, 0.35),
                "allowed_categories": ["general", "habitat", "structure"],
                "job_filters": [],
        },
        ZONE_TYPE_STORAGE: {
                "display_name": "Logistics",
                "color": Color(0.95, 0.75, 0.3, 0.35),
                "allowed_categories": ["storage", "structure"],
                "job_filters": ["generalist", "quartermaster"],
        },
        ZONE_TYPE_INDUSTRIAL: {
                "display_name": "Industrial",
                "color": Color(1.0, 0.4, 0.4, 0.35),
                "allowed_categories": ["industry", "power", "structure"],
                "job_filters": ["generalist", "engineer"],
        },
}

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
}

var main
var overlay: TileMap
var active_zone_type: String = ZONE_TYPE_UNASSIGNED

var _zone_mode_active: bool = false
var _is_dragging: bool = false
var _painted_tiles: Dictionary = {}

func _init(main_ref, overlay_map: TileMap):
        main = main_ref
        overlay = overlay_map
        if overlay:
                overlay.clear()
                overlay.z_index = 5
                overlay.modulate = Color(1, 1, 1, 0.6)

func initialize_zone_map():
        main.zone_map.clear()
        if overlay:
                overlay.clear()

func ensure_zone(tile_pos: Vector2i, default_zone: String = ZONE_TYPE_GENERAL):
        if not main.zone_map.has(tile_pos):
                main.zone_map[tile_pos] = default_zone
                _update_overlay(tile_pos, default_zone)
        else:
                _update_overlay(tile_pos, main.zone_map[tile_pos])

func set_zone(tile_pos: Vector2i, zone_type: String):
        if not ZONE_DEFINITIONS.has(zone_type):
                zone_type = ZONE_TYPE_UNASSIGNED
        main.zone_map[tile_pos] = zone_type
        _update_overlay(tile_pos, zone_type)

func refresh_overlay_from_map():
        if not overlay:
                return
        overlay.clear()
        for tile_pos in main.zone_map.keys():
                _update_overlay(tile_pos, main.zone_map[tile_pos])

func start_zone_mode(zone_type: String):
        if not ZONE_DEFINITIONS.has(zone_type):
                zone_type = ZONE_TYPE_UNASSIGNED
        active_zone_type = zone_type
        _zone_mode_active = true
        _painted_tiles.clear()
        var mode_name = get_zone_name(active_zone_type)
        if active_zone_type == ZONE_TYPE_UNASSIGNED:
                print("Zone paint mode: Clearing assignments. Left-click and drag to erase, Right-click to cancel.")
        else:
                print("Zone paint mode: %s. Left-click and drag to paint, Right-click to cancel." % mode_name)

func cancel_zone_mode():
        var was_active = _zone_mode_active or _is_dragging
        _zone_mode_active = false
        _is_dragging = false
        _painted_tiles.clear()
        active_zone_type = ZONE_TYPE_UNASSIGNED
        if was_active:
                print("Zone paint mode canceled.")

func is_zone_mode_active() -> bool:
        return _zone_mode_active

func begin_paint(world_position: Vector2):
        if not _zone_mode_active:
                return
        _is_dragging = true
        _apply_zone(world_position)

func continue_paint(world_position: Vector2):
        if not _zone_mode_active or not _is_dragging:
                return
        _apply_zone(world_position)

func end_paint():
        _is_dragging = false
        _painted_tiles.clear()

func get_zone_type(tile_pos: Vector2i) -> String:
        return main.zone_map.get(tile_pos, ZONE_TYPE_UNASSIGNED)

func get_zone_definition(zone_type: String) -> Dictionary:
        return ZONE_DEFINITIONS.get(zone_type, ZONE_DEFINITIONS[ZONE_TYPE_UNASSIGNED])

func get_zone_info_for_tile(tile_pos: Vector2i) -> Dictionary:
        var zone_type = get_zone_type(tile_pos)
        return get_zone_definition(zone_type)

func get_zone_name(zone_type: String) -> String:
        return get_zone_definition(zone_type).get("display_name", zone_type.capitalize())

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

func _apply_zone(world_position: Vector2):
        var tile_pos = main.tilemap.local_to_map(world_position)
        if _painted_tiles.has(tile_pos):
                return
        _painted_tiles[tile_pos] = true
        set_zone(tile_pos, active_zone_type)

func _update_overlay(tile_pos: Vector2i, zone_type: String):
        if not overlay:
                return
        if zone_type == ZONE_TYPE_UNASSIGNED:
                overlay.erase_cell(0, tile_pos)
                return

        overlay.set_cell(0, tile_pos, 0, Vector2i(0, 0))
        var tile_data: TileData = overlay.get_cell_tile_data(0, tile_pos)
        if tile_data:
                tile_data.modulate = get_zone_definition(zone_type).get("color", Color.TRANSPARENT)
