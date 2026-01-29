class_name Checkpoint
extends Area2D
## Checkpoint that updates the respawn point when the player touches it.
## Place in levels to provide save points during gameplay.

@onready var flag: Polygon2D = $Flag

var _activated := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _activated:
		return

	# Check if it's the player
	if body.has_method("die"):
		_activate()

func _activate() -> void:
	_activated = true
	GameManager.register_respawn_point(self)

	# Visual feedback - change flag to green
	var tween = create_tween()
	tween.tween_property(flag, "color", Color(0.2, 0.9, 0.3, 1.0), 0.2)
	tween.parallel().tween_property(flag, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(flag, "scale", Vector2(1.0, 1.0), 0.1)
