class_name RespawnPoint
extends Marker2D

func _ready() -> void:
	GameManager.register_respawn_point(self)
