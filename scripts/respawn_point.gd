class_name RespawnPoint
extends Marker2D
## Initial spawn point for the level. This is where the player starts and
## where they respawn if no checkpoint has been activated.

func _ready() -> void:
	GameManager.register_respawn_point(self, true)
