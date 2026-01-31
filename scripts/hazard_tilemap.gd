class_name hazard_tilemap
extends TileMapLayer

## TileMapLayer that auto-generates Area2D hazard zones for tiles with is_deadly custom data.
## Attach this script to a TileMapLayer instead of maskable_tilemap.gd,
## or use it alongside by keeping both scripts on separate layers.
##
## When toggled off, swaps tiles to greyscale and disables hazard Area2Ds
## so the player can see where hazards are without being killed by them.

## The source ID in the TileSet for normal (colored) tiles.
@export var source_normal: int = 0

## The source ID in the TileSet for greyscale (disabled) tiles.
## Set to -1 to disable greyscale swapping (falls back to hiding the layer).
@export var source_greyscale: int = -1

## Whether the greyscale source exists in the TileSet.
## Checked once at startup so we don't query every bit change.
var _has_greyscale: bool = false

func _ready() -> void:
	# Disable tile physics — hazard detection uses generated Area2Ds instead
	collision_enabled = false
	GameManager.register_tilemap(self)
	_generate_hazard_areas()
	# Check if the greyscale atlas source actually exists in the TileSet.
	# If not, we fall back to the old show/hide behavior until it's added.
	if source_greyscale >= 0 and tile_set and tile_set.has_source(source_greyscale):
		_has_greyscale = true

func _exit_tree() -> void:
	GameManager.unregister_tilemap(self)

func on_bit_changed(bit_enabled: bool) -> void:
	# Toggle hazard Area2Ds so disabled hazards don't kill the player
	for child in get_children():
		if child is Area2D:
			child.monitoring = bit_enabled

	if _has_greyscale:
		# Swap tiles between normal and greyscale.
		# The tilemap stays visible either way so the player can see where hazards are.
		var target_source = source_normal if bit_enabled else source_greyscale
		for coords in get_used_cells():
			var atlas_coords = get_cell_atlas_coords(coords)
			var alt = get_cell_alternative_tile(coords)
			set_cell(coords, target_source, atlas_coords, alt)
	else:
		# No greyscale source yet — just hide/show the whole layer
		visible = bit_enabled

func _generate_hazard_areas() -> void:
	var used_cells := get_used_cells()
	for cell_coords in used_cells:
		var data := get_cell_tile_data(cell_coords)
		if data == null:
			continue

		var is_deadly = data.get_custom_data("is_deadly")
		if not is_deadly:
			continue

		_create_hazard_area(cell_coords)

func _create_hazard_area(cell_coords: Vector2i) -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1  # Detect player (layer 1)
	area.monitorable = false

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var tile_size := tile_set.tile_size
	rect.size = Vector2(tile_size)
	shape.shape = rect

	# Position at the center of the tile in local coords
	var local_pos := map_to_local(cell_coords)
	area.position = local_pos

	area.add_child(shape)
	add_child(area)

	area.body_entered.connect(_on_hazard_body_entered)

func _on_hazard_body_entered(body: Node2D) -> void:
	if body.has_method("die"):
		body.die()
