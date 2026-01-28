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
## Maps bit_index -> registered object (Node)
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
## Returns true if registration succeeded, false if bit already taken.
func register_object(bit_index: int, object: Node) -> bool:
	if bit_index < 0 or bit_index >= max_bits:
		push_error("GameManager: bit_index %d out of range (0-%d)" % [bit_index, max_bits - 1])
		return false

	if _registered_objects.has(bit_index):
		push_warning("GameManager: bit %d already has a registered object, replacing" % bit_index)

	_registered_objects[bit_index] = object

	# Immediately notify the object of current state
	_notify_registered_object(bit_index, is_bit_set(bit_index))

	# Auto-unregister when object is freed
	if not object.tree_exiting.is_connected(_on_registered_object_exiting.bind(bit_index)):
		object.tree_exiting.connect(_on_registered_object_exiting.bind(bit_index))

	return true

## Unregister an object from its bit index.
func unregister_object(bit_index: int) -> void:
	_registered_objects.erase(bit_index)

## Get the object registered to a bit index (or null).
func get_registered_object(bit_index: int) -> Node:
	return _registered_objects.get(bit_index)

## Called by a registered object to flip its own bit.
## Use this when something in the world affects the bit (e.g., bomb destroys obstacle).
func object_requests_bit_change(bit_index: int, enabled: bool) -> void:
	set_bit(bit_index, enabled)

## Internal: notify a registered object of its bit state change.
func _notify_registered_object(bit_index: int, enabled: bool) -> void:
	var object = _registered_objects.get(bit_index)
	if object and is_instance_valid(object) and object.has_method("on_bit_changed"):
		object.on_bit_changed(enabled)

## Internal: auto-cleanup when registered object leaves tree.
func _on_registered_object_exiting(bit_index: int) -> void:
	_registered_objects.erase(bit_index)

# --- Game Flow ---

func reset_level() -> void:
	bitmask = 0
	chip_health = chip_max_health

func reset_game() -> void:
	reset_level()
	current_level = 1

func damage_chip(amount: int = 1) -> void:
	chip_health -= amount

func heal_chip(amount: int = 1) -> void:
	chip_health = min(chip_health + amount, chip_max_health)

func complete_level() -> void:
	level_completed.emit()
