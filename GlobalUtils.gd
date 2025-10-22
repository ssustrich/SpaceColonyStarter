extends Node

# This script is registered as an Autoload (Singleton) named "GlobalUtils"
# and provides reusable TileMap and utility functions accessible globally.

## Atlas Source ID (Assumes a single TileSet Atlas is imported)
const ATLAS_SOURCE_ID = 0

## Layer Indexing (Provided here for reference, but defined in main game logic)
const LAYER_HULL = 0
const LAYER_FLOOR = 1
const LAYER_BLUEPRINT = 2

# ==============================================================================
# TILEMAP UTILITIES
# ==============================================================================

## Sets a cell on a specific layer of the TileMap, correctly handling the source ID.
func _set_layer_cell(tilemap: TileMap, layer: int, coords: Vector2i, atlas_coords: Vector2i):
	# -1 clears the cell; otherwise, use the fixed ATLAS_SOURCE_ID
	var source_id = ATLAS_SOURCE_ID if atlas_coords != Vector2i(-1, -1) else -1
	tilemap.set_cell(layer, coords, source_id, atlas_coords)


## Checks if a tile at the given position is pressurized (i.e., has a floor tile).
func is_tile_pressurized(tilemap: TileMap, tile_pos: Vector2i, floor_layer: int) -> bool:
	# A tile is pressurized if it has a floor tile on the floor layer
	return tilemap.get_cell_source_id(floor_layer, tile_pos) != -1

## Checks if a tile is adjacent to an existing floor tile. Used for blueprint validation.
func is_adjacent_to_floor(tilemap: TileMap, tile_pos: Vector2i, floor_layer: int) -> bool:
	# Directions: N, S, E, W
	var neighbors: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)
	]
	
	for offset in neighbors:
		if is_tile_pressurized(tilemap, tile_pos + offset, floor_layer):
			return true
	return false

## Returns the custom type string (e.g., "hull", "floor") of a tile based on its Atlas coords.
func get_tile_type(tilemap: TileMap, tile_pos: Vector2i, layer: int) -> String:
	# We only care about tiles placed on the hull or floor layers for type checking
	
	var source_id = tilemap.get_cell_source_id(layer, tile_pos)
	if source_id == -1:
		return "" # Void/Empty Tile

	var atlas_coords = tilemap.get_cell_atlas_coords(layer, tile_pos)
	
	# NOTE: This function relies on a centralized database check which is complex for a utility script.
	# For now, we will use hardcoded Atlas coords derived from the MODULE_DATABASE JSON structure
	
	# Based on modules.json:
	if atlas_coords == Vector2i(1, 0): return "hull"
	if atlas_coords == Vector2i(0, 0): return "floor"
	if atlas_coords == Vector2i(3, 0): return "solar_collector"
	if atlas_coords == Vector2i(5, 0): return "void_drill"
	
	return "occupied" # Generic occupied tile
