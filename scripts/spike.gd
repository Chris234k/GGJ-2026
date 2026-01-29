class_name Spike
extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func on_bit_changed(enabled: bool) -> void:
	visible = enabled
	monitoring = enabled

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("die"):
		body.die()
