class_name Teleporter
extends Area2D
## Paired teleporter that transports Chip from entry to exit on contact.
## Place two Teleporter instances in a level and link them to each other
## via the paired_teleporter export in the Inspector.
##
## Supports MaskableBehavior for bitmask toggling (show/hide + enable/disable).
##
## Any body that should be teleportable must implement:
##   teleport(destination: Vector2) -> void
## Currently only the Player implements this. The NPC does not, so it
## will walk through teleporters without being affected.

## Path to the other teleporter this one sends bodies to. Set in the Inspector.
@export var paired_teleporter: NodePath

## How long (in seconds) the exit teleporter ignores collisions after receiving
## a body. This prevents the classic "infinite teleport loop" where arriving at
## the exit immediately triggers it to send you back.
@export var cooldown_duration: float = 0.5

## Reference to the Sprite2D child node, used for the flash visual effect.
## @onready means this is set automatically when the node enters the scene tree.
@onready var sprite: Sprite2D = $Sprite2D

## How fast the sprite rotates, in radians per second.
## PI means a full 180° turn per second (a full spin takes 2 seconds).
@export var spin_speed: float = PI * 0.25

## How fast the scale pulses (higher = faster breathing).
@export var pulse_speed: float = 3.0

## How much the scale grows/shrinks from its base size.
## 0.1 means it oscillates between 90% and 110% of its normal scale.
@export var pulse_amount: float = 0.04

## When true, this teleporter won't activate. Used to prevent infinite loops:
## the exit teleporter is put on cooldown right before the body arrives.
var _is_on_cooldown: bool = false

## Tracks total elapsed time for the pulse animation.
## We feed this into sin() to get a smooth oscillation.
var _time: float = 0.0

## The sprite's original scale from the scene, captured at startup.
## The pulse animation multiplies this so it always works relative to
## whatever scale you set in the Inspector.
var _base_sprite_scale: Vector2

func _ready() -> void:
	# Area2D emits body_entered when a physics body overlaps our CollisionShape2D.
	# We connect that signal to our handler so we know when something steps in.
	body_entered.connect(_on_body_entered)

	# Capture the sprite's scale as set in the scene so the pulse animation
	# can use it as a baseline. Change the scale in the Inspector and the
	# animation will automatically adapt — no hardcoded values needed.
	if sprite:
		_base_sprite_scale = sprite.scale

func _process(delta: float) -> void:
	if sprite == null:
		return

	# Accumulate time so our animations progress smoothly each frame
	_time += delta

	# Rotate the sprite continuously. delta ensures consistent speed
	# regardless of frame rate (e.g. at 60fps, delta ≈ 0.016 seconds).
	sprite.rotation += spin_speed * delta

	# Pulse the scale using sin() for a smooth "breathing" effect.
	# sin() outputs -1 to 1, so we multiply by pulse_amount to get
	# a small oscillation (e.g. 0.9 to 1.1 with pulse_amount = 0.1).
	# We use the sprite's base scale (set in the scene) as the center point.
	var pulse: float = 1.0 + sin(_time * pulse_speed) * pulse_amount
	sprite.scale = _base_sprite_scale * pulse

func _on_body_entered(body: Node2D) -> void:
	# --- Guard checks: bail out early if we shouldn't teleport ---

	# This teleporter is on cooldown (something just arrived here)
	if _is_on_cooldown:
		return

	# The body doesn't have a teleport() method, so it's not teleportable
	# (e.g. the NPC, or any other physics body that wanders in)
	if not body.has_method("teleport"):
		return

	# Look up the paired teleporter. If it's missing or invalid, do nothing.
	var target := _get_paired_teleporter()
	if target == null:
		return

	# The exit teleporter has been disabled via bitmask — don't send Chip
	# to a teleporter that's turned off. "monitoring" is the Area2D property
	# that controls whether it detects collisions; we also use it as our
	# "is this teleporter active?" flag in on_bit_changed().
	if not target.monitoring:
		return

	# --- All checks passed, do the teleport ---

	# IMPORTANT: Set cooldown on the EXIT teleporter BEFORE moving the body.
	# When we move Chip to the exit's position, Godot will fire body_entered
	# on the exit teleporter. The cooldown flag makes that second trigger
	# get ignored, preventing an infinite A→B→A→B loop.
	target._is_on_cooldown = true

	# Ask the body to teleport itself (the Player handles its own position
	# and velocity reset inside its teleport() method)
	body.teleport(target.global_position)

	# Visual feedback: flash both teleporters so the player sees what happened
	_flash()
	target._flash()

	# Start a timer to re-enable the exit teleporter after the cooldown.
	# This allows bidirectional teleportation — once the cooldown expires,
	# Chip can step into the exit to go back.
	target._start_cooldown_timer()

## Looks up the paired teleporter node from the exported NodePath.
## Returns null if the path is empty or the node no longer exists.
func _get_paired_teleporter() -> Teleporter:
	if paired_teleporter.is_empty():
		return null
	# get_node_or_null returns null instead of crashing if the path is invalid
	var node = get_node_or_null(paired_teleporter)
	if not is_instance_valid(node):
		return null
	return node as Teleporter

## Waits for cooldown_duration seconds, then re-arms this teleporter.
## Uses Godot's built-in SceneTree timer — "await" pauses this function
## until the timer fires, then execution resumes on the next line.
func _start_cooldown_timer() -> void:
	await get_tree().create_timer(cooldown_duration).timeout
	_is_on_cooldown = false

## Plays a brief cyan flash on the sprite to indicate teleporter activation.
## Uses a Tween to animate the "modulate" property (a color multiplier that
## tints the entire sprite). Fades to cyan, then back to white (normal).
func _flash() -> void:
	if sprite == null:
		return
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.3, 1.0, 1.0, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

## Called by MaskableBehavior when this teleporter's bit is toggled.
## Shows/hides the teleporter and enables/disables its collision detection.
## "monitoring" controls whether the Area2D detects bodies entering it.
func on_bit_changed(enabled: bool) -> void:
	visible = enabled
	monitoring = enabled
	# Reset cooldown when re-enabled so the teleporter is immediately usable
	if enabled:
		_is_on_cooldown = false
