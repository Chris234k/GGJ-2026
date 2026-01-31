extends Node
## GameManager - Autoload Singleton
## Central source of truth for all game state.
## Access from anywhere: GameManager.bitmask, GameManager.set_bit(0, true), etc.

# --- Signals ---
signal bitmask_updated(new_mask: int)
signal bit_toggled(bit_index: int, enabled: bool)
signal chip_health_changed(new_health: int)
signal chip_died
signal level_completed
signal max_bits_changed(new_max: int)
signal checkpoint_activated(checkpoint: Vector2)

# --- Bit Colors ---
## Color assigned to each bit index, used for visual feedback (outlines, HUD, etc.).
## Intentionally bright/saturated so they stand out against greyscale tiles.
const BIT_COLORS: Array[Color] = [
	Color(1.0, 0.2, 0.2),   # 0: Red
	Color(0.3, 0.5, 1.0),   # 1: Blue
	Color(0.7, 0.2, 1.0),   # 2: Violet
	Color(1.0, 0.9, 0.2),   # 3: Yellow
	Color(1.0, 0.3, 0.8),   # 4: Magenta
	Color(0.3, 1.0, 1.0),   # 5: Cyan
	Color(1.0, 0.6, 0.1),   # 6: Orange
	Color(0.7, 0.3, 1.0),   # 7: Purple
	Color(1.0, 0.5, 0.5),   # 8: Light Red
	Color(0.5, 0.7, 1.0),   # 9: Light Blue
	Color(0.8, 0.5, 1.0),   # 10: Light Violet
	Color(1.0, 1.0, 0.5),   # 11: Light Yellow
	Color(1.0, 0.6, 0.9),   # 12: Light Magenta
	Color(0.6, 1.0, 1.0),   # 13: Light Cyan
	Color(1.0, 0.8, 0.5),   # 14: Light Orange
	Color(0.8, 0.6, 1.0),   # 15: Light Purple
]

## Get the color for a given bit index. Returns white if out of range.
static func get_bit_color(bit_index: int) -> Color:
	if bit_index >= 0 and bit_index < BIT_COLORS.size():
		return BIT_COLORS[bit_index]
	return Color.WHITE

# --- Bitmask State ---
## The current bitmask controlling level objects.
## Each bit (0-7 for 8-bit, 0-15 for 16-bit, etc.) maps to a maskable object.
var bitmask: int = 0:
	set(value):
		var old_mask = bitmask
		bitmask = value
		bitmask_updated.emit(bitmask)
		# Emit individual bit changes for objects that want granular updates
		for i in range(max_bits):
			var old_bit = (old_mask >> i) & 1
			var new_bit = (value >> i) & 1
			if old_bit != new_bit:
				bit_toggled.emit(i, new_bit == 1)
				# Notify registered object directly
				_notify_registered_object(i, new_bit == 1)
				

## Maximum number of bits for current level (difficulty modifier)
## Higher = more objects to manage = harder
var max_bits: int = 4:
	set(value):
		max_bits = clampi(value, 1, 16)  # Sane limits: 1-16 bits
		max_bits_changed.emit(max_bits)

# --- Object Registry ---
## Maps bit_index -> Array of registered objects (Nodes)
## Multiple objects can share the same bit index.
## Objects must implement: on_bit_changed(enabled: bool)
var _registered_objects: Dictionary = {}

# --- Chip State ---
var chip_health: int = 3:
	set(value):
		chip_health = value
		chip_health_changed.emit(chip_health)
		if chip_health <= 0:
			chip_died.emit()

var chip_max_health: int = 3

# --- Respawn ---
var _respawn_point := Vector2.ZERO
var _initial_respawn_point := Vector2.ZERO
var _player: CharacterBody2D = null

## Register a respawn point. If is_initial is true, also stores as the initial
## spawn point for level resets.
func register_respawn_point(point: Vector2, is_initial: bool = false) -> void:
	_respawn_point = point
	if is_initial:
		_initial_respawn_point = point
	elif _initial_respawn_point != null and point != _initial_respawn_point:
		# This is a checkpoint activation
		checkpoint_activated.emit(point)

func register_player(player: CharacterBody2D) -> void:
	_player = player

func get_respawn_position() -> Vector2:
	if _respawn_point:
		return _respawn_point
	push_warning("GameManager: No respawn point registered, using origin")
	return Vector2.ZERO

func notify_chip_died() -> void:
	chip_died.emit()

## Reset the respawn point to the initial spawn point.
## Call this on level reset to clear checkpoint progress.
func reset_checkpoints() -> void:
	if _initial_respawn_point:
		_respawn_point = _initial_respawn_point

# --- Progress ---
var current_level: int = 1

# --- Bitmask Helper Functions ---

## Check if a specific bit is enabled
func is_bit_set(bit_index: int) -> bool:
	return (bitmask >> bit_index) & 1 == 1

## Set a specific bit to enabled (true) or disabled (false)
func set_bit(bit_index: int, enabled: bool) -> void:
	if enabled:
		bitmask = bitmask | (1 << bit_index)
	else:
		bitmask = bitmask & ~(1 << bit_index)

## Toggle a specific bit
func toggle_bit(bit_index: int) -> void:
	bitmask = bitmask ^ (1 << bit_index)

## Set the entire bitmask from a binary string like "10110010"
func set_from_binary_string(binary_str: String) -> void:
	var new_mask: int = 0
	var bit_index: int = 0
	# Read right-to-left (LSB first)
	for i in range(binary_str.length() - 1, -1, -1):
		if binary_str[i] == "1":
			new_mask = new_mask | (1 << bit_index)
		bit_index += 1
	bitmask = new_mask

## Get the bitmask as a binary string (padded to max_bits)
func get_binary_string() -> String:
	var result: String = ""
	for i in range(max_bits - 1, -1, -1):
		result += "1" if is_bit_set(i) else "0"
	return result

# --- Object Registration ---

## Register an object to a specific bit index.
## The object should implement: on_bit_changed(enabled: bool)
## Multiple objects can register to the same bit index.
func register_object(bit_index: int, object: Node) -> bool:
	if bit_index < 0 or bit_index >= max_bits:
		push_error("GameManager: bit_index %d out of range (0-%d)" % [bit_index, max_bits - 1])
		return false

	# Create array for this bit if it doesn't exist
	if not _registered_objects.has(bit_index):
		_registered_objects[bit_index] = []

	# Add object to the array (avoid duplicates)
	var objects_array: Array = _registered_objects[bit_index]
	if object not in objects_array:
		objects_array.append(object)

	# Immediately notify this object of current state
	if object.has_method("on_bit_changed"):
		object.on_bit_changed(is_bit_set(bit_index))

	# Auto-unregister when object is freed
	var cleanup_callable = _on_registered_object_exiting.bind(bit_index, object)
	if not object.tree_exiting.is_connected(cleanup_callable):
		object.tree_exiting.connect(cleanup_callable)

	return true

## Unregister a specific object from its bit index.
func unregister_object(bit_index: int, object: Node = null) -> void:
	if not _registered_objects.has(bit_index):
		return

	if object == null:
		# Remove all objects at this bit index
		_registered_objects.erase(bit_index)
	else:
		# Remove specific object from array
		var objects_array: Array = _registered_objects[bit_index]
		objects_array.erase(object)
		# Clean up empty arrays
		if objects_array.is_empty():
			_registered_objects.erase(bit_index)

## Get the first object registered to a bit index (or null).
func get_registered_object(bit_index: int) -> Node:
	if not _registered_objects.has(bit_index):
		return null
	var objects_array: Array = _registered_objects[bit_index]
	if objects_array.is_empty():
		return null
	return objects_array[0]

## Get all objects registered to a bit index.
func get_registered_objects(bit_index: int) -> Array:
	if not _registered_objects.has(bit_index):
		return []
	return _registered_objects[bit_index]

## Called by a registered object to flip its own bit.
## Use this when something in the world affects the bit (e.g., bomb destroys obstacle).
func object_requests_bit_change(bit_index: int, enabled: bool) -> void:
	set_bit(bit_index, enabled)

## Internal: notify all registered objects at a bit index of state change.
func _notify_registered_object(bit_index: int, enabled: bool) -> void:
	if not _registered_objects.has(bit_index):
		return
	var objects_array: Array = _registered_objects[bit_index]
	for object in objects_array:
		if is_instance_valid(object) and object.has_method("on_bit_changed"):
			object.on_bit_changed(enabled)

## Internal: auto-cleanup when registered object leaves tree.
func _on_registered_object_exiting(bit_index: int, object: Node) -> void:
	unregister_object(bit_index, object)

# --- Game Flow ---

func reset_level(reset_checkpoint_progress: bool = false) -> void:
	bitmask = 0
	chip_health = chip_max_health
	if reset_checkpoint_progress:
		reset_checkpoints()

func reset_game() -> void:
	clear_all_registrations()
	reset_level(true)
	current_level = 1

## Clear all registered objects, tilemaps, respawn points, and player reference.
## Call between level transitions to prevent stale references.
func clear_all_registrations() -> void:
	_registered_objects.clear()
	level_tilemaps.clear()
	_respawn_point = Vector2.ZERO
	_initial_respawn_point = Vector2.ZERO
	_player = null

func damage_chip(amount: int = 1) -> void:
	chip_health -= amount

func heal_chip(amount: int = 1) -> void:
	chip_health = min(chip_health + amount, chip_max_health)

func complete_level() -> void:
	level_completed.emit()


# --- Level Tilemaps ---

var level_tilemaps: Array[TileMapLayer]

## Register a single tilemap for tile data checking (is_deadly, jump_force, etc.)
func register_tilemap(tilemap: TileMapLayer) -> void:
	if tilemap not in level_tilemaps:
		level_tilemaps.append(tilemap)

## Unregister a tilemap (call when tilemap exits tree)
func unregister_tilemap(tilemap: TileMapLayer) -> void:
	level_tilemaps.erase(tilemap)

## Bulk register (kept for backwards compatibility)
func register_tilemaps(tilemaps: Array[TileMapLayer]) -> void:
	for tilemap in tilemaps:
		register_tilemap(tilemap)
