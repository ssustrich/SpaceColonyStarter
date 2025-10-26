	
	# GlobalUtils.gd
extends Node

const ATLAS_SOURCE_ID = 0

const LAYER_HULL = 0
const LAYER_FLOOR = 1
const LAYER_BLUEPRINT = 2

var _main: Node2D = null

func register_main(node: Node2D) -> void:
		_main = node

func _set_layer_cell(tilemap: TileMap, layer: int, coords: Vector2i, atlas_coords: Vector2i):
		var source_id = ATLAS_SOURCE_ID if atlas_coords != Vector2i(-1, -1) else -1
		tilemap.set_cell(layer, coords, source_id, atlas_coords)

func _set_layer_cell_w_atlas(tilemap: TileMap, layer: int, coords: Vector2i, atlas_coords: Vector3i):
	# -1 clears the cell; otherwise, use the fixed ATLAS_SOURCE_ID
	var source_id = atlas_coords[0] if atlas_coords != Vector3i(0, -1, -1) else -1
	tilemap.set_cell(layer, coords, source_id, Vector2i(atlas_coords[1], atlas_coords[2]) )

func is_tile_pressurized(tilemap: TileMap, tile_pos: Vector2i, floor_layer: int) -> bool:
		return tilemap.get_cell_source_id(floor_layer, tile_pos) != -1

func is_adjacent_to_floor(tilemap: TileMap, tile_pos: Vector2i, floor_layer: int) -> bool:
		var neighbors: Array[Vector2i] = [
				Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)
		]

		for offset in neighbors:
				if is_tile_pressurized(tilemap, tile_pos + offset, floor_layer):
						return true
		return false

func get_tile_type(tilemap: TileMap, tile_pos: Vector2i, layer: int) -> String:
		if tilemap.get_cell_source_id(layer, tile_pos) == -1:
				return ""

		var main_node := _main
		if main_node == null:
				main_node = get_tree().root.get_node_or_null("main") as Node2D
				_main = main_node

		if main_node == null:
				return ""

		var atlas_coords := tilemap.get_cell_atlas_coords(layer, tile_pos)
		var lookup: Dictionary = main_node.MODULE_DATABASE_RLUT.get(atlas_coords, {})
		if lookup.is_empty():
				return "occupied"

		return String(lookup.get("type", ""))
