extends Camera2D
## Camera Zoom Toggle - Lets the player survey the entire level.
##
## Attach this script to the Camera2D node inside the Player scene.
## Press Z to toggle between two modes:
##   - "Follow" mode (default): camera follows the player with a 2x zoom and offset.
##   - "Overview" mode: camera zooms out to show all tilemaps in the level.
##
## Key Godot concepts used here:
##   - top_level: When true, the node ignores its parent's transform and positions
##     itself in global space. We need this for overview mode because the camera is
##     a child of the Player — without top_level, it would always follow the player.
##     Setting top_level = false re-attaches it to the player's transform.
##   - Tween: Smoothly interpolates properties over time. We tween zoom, position,
##     and offset simultaneously for a polished transition.

# -- Constants --

## How long the zoom transition takes (in seconds).
const TWEEN_DURATION := 0.4

## Extra padding around the level bounds (in pixels) so edge tiles aren't
## right at the screen border. 32px = 2 tiles.
const BOUNDS_MARGIN := 32.0

## Minimum zoom to prevent extreme zoom-out on very large levels.
const MIN_ZOOM := 0.1

# -- State --

## Tracks whether we're currently in overview (zoomed-out) mode.
var _is_zoomed_out := false

## Reference to the active tween so we can interrupt it if the player
## presses Z mid-transition. Killing a finished tween is safe (no-op).
var _active_tween: Tween = null

## The default zoom and offset, captured from the node at _ready().
## This avoids hardcoding values and stays in sync with the scene file.
var _default_zoom := Vector2(2, 2)
var _default_offset := Vector2(150, 0)

## Stored at the start of zoom-in so we can lerp from overview → player.
var _zoom_in_start_pos := Vector2.ZERO


func _ready() -> void:
	# Capture whatever zoom/offset is set in the Inspector as our defaults.
	_default_zoom = zoom
	_default_offset = offset

	# Scale the background image up so it covers the full level bounds.
	# The background is a gradient, so scaling it larger is visually seamless
	# and avoids black borders when the camera zooms out to overview mode.
	# We do this once at startup rather than animating it per-zoom, which
	# eliminates any visual pop during transitions.
	_scale_background_to_level()


func _unhandled_input(event: InputEvent) -> void:
	# Uses the "zoom_toggle" input action defined in Project Settings > Input Map.
	# This follows the same pattern as toggle_bit_0..3 for gameplay keys.
	# (Debug keys like N/P/Shift+R in game.gd use raw keycodes instead.)
	if event.is_action_pressed("zoom_toggle"):
		_toggle_zoom()


func _toggle_zoom() -> void:
	# If a tween is still running, kill it so we can start a new one
	# from wherever the current interpolated values are.
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	if _is_zoomed_out:
		_zoom_in()
	else:
		_zoom_out()


# -- Zoom Out (Follow → Overview) --

func _zoom_out() -> void:
	_is_zoomed_out = true

	# Calculate where and how far to zoom
	var bounds := _calculate_level_bounds()
	var target_zoom := _calculate_overview_zoom(bounds)
	var target_position := bounds.get_center()

	# Enable top_level BEFORE tweening so the camera positions itself in
	# global space. Without this, global_position would be relative to the
	# player and the tween target wouldn't make sense.
	top_level = true

	# Start the global_position from the player's current position so there's
	# no sudden jump when we flip top_level on.
	global_position = get_parent().global_position

	# Tween all three properties simultaneously for a smooth transition.
	_active_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_active_tween.set_parallel(true)
	_active_tween.tween_property(self, "zoom", target_zoom, TWEEN_DURATION)
	_active_tween.tween_property(self, "global_position", target_position, TWEEN_DURATION)
	_active_tween.tween_property(self, "offset", Vector2.ZERO, TWEEN_DURATION)


# -- Zoom In (Overview → Follow) --

func _zoom_in() -> void:
	_is_zoomed_out = false

	# We can't tween global_position to a fixed point because the player keeps
	# moving during the transition. Instead we use tween_method with a 0→1
	# progress value, and each frame we lerp toward the player's *current*
	# position. This tracks the moving target so there's no snap at the end.
	_zoom_in_start_pos = global_position

	_active_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_active_tween.set_parallel(true)
	_active_tween.tween_property(self, "zoom", _default_zoom, TWEEN_DURATION)
	_active_tween.tween_method(_lerp_toward_player, 0.0, 1.0, TWEEN_DURATION)
	_active_tween.tween_property(self, "offset", _default_offset, TWEEN_DURATION)

	# After the tween finishes, turn off top_level so the camera re-attaches
	# to the player's transform and resumes following automatically.
	_active_tween.chain().tween_callback(_finish_zoom_in)


func _lerp_toward_player(progress: float) -> void:
	## Called each tween frame during zoom-in with progress going from 0.0 to 1.0.
	## Instead of tweening toward a fixed position (which goes stale as the player
	## moves), we re-read the player's current global_position every frame and
	## lerp between our starting position and wherever the player is RIGHT NOW.
	## At progress=1.0 we're exactly on the player, so there's no snap.
	var player_pos: Vector2 = get_parent().global_position
	global_position = _zoom_in_start_pos.lerp(player_pos, progress)


func _finish_zoom_in() -> void:
	# IMPORTANT: Reset local position before re-attaching to the player.
	# While top_level was true, "position" was being used as a global coordinate
	# (e.g., (500, 300) for the level center). If we just set top_level = false,
	# that same value gets reinterpreted as a local offset from the Player,
	# which would push the camera way off to the side. Zeroing it first ensures
	# the camera sits exactly on the Player when it re-attaches.
	position = Vector2.ZERO
	top_level = false


# -- Background Scaling --

func _scale_background_to_level() -> void:
	## Scales the BackgroundImage sprite large enough to cover the screen at any
	## camera position and zoom level. The background is a gradient, so oversizing
	## it is visually free — no need to calculate exact coverage.
	var player := get_parent()
	if not player:
		return
	var level_root := player.get_parent()
	if not level_root:
		return

	var bg_parallax := level_root.get_node_or_null("BackgroundLayer") as Parallax2D
	if not bg_parallax:
		return
	var bg_image := bg_parallax.get_node_or_null("BackgroundImage") as Sprite2D
	if not bg_image or not bg_image.texture:
		return

	var bounds := _calculate_level_bounds()

	const BG_SCALE := 3.0
	bg_image.scale = Vector2(BG_SCALE, BG_SCALE)
	bg_image.position = bounds.get_center()


# -- Level Bounds Calculation --

func _calculate_level_bounds() -> Rect2:
	## Computes a bounding rectangle that encompasses the full level:
	##   1. Every tile across all registered tilemaps
	##   2. Every Node2D child of the level root (teleporters, player, etc.)
	## This ensures the overview camera shows everything placed in the level,
	## not just the tilemap geometry.

	var bounds := Rect2()
	var first := true
	var tile_size := Vector2(16, 16)  # From project settings: tiles are 16x16

	for tilemap in GameManager.level_tilemaps:
		if not is_instance_valid(tilemap):
			continue

		var cells := tilemap.get_used_cells()
		for cell in cells:
			# map_to_local() gives the center of the tile in tilemap-local space.
			var local_pos: Vector2 = tilemap.map_to_local(cell)
			# to_global() converts to world coordinates.
			var global_pos: Vector2 = tilemap.to_global(local_pos)

			# Build a small rect for this tile (centered on global_pos, size = tile_size).
			var tile_rect := Rect2(global_pos - tile_size / 2.0, tile_size)

			if first:
				bounds = tile_rect
				first = false
			else:
				bounds = bounds.merge(tile_rect)

	# Also include non-tilemap Node2D children of the level root (teleporters,
	# checkpoints, etc.) so the overview shows every object in the level.
	var level_root := get_parent().get_parent()  # Player → Level root
	if level_root:
		for child in level_root.get_children():
			if child is Node2D and not child is Parallax2D:
				var point := Rect2((child as Node2D).global_position, Vector2.ZERO)
				if first:
					bounds = point
					first = false
				else:
					bounds = bounds.merge(point)

	# If nothing was found (empty level?), return a fallback centered on origin
	if first:
		bounds = Rect2(-640, -360, 1280, 720)

	# Add margin so objects at the edges aren't pressed against the screen border
	bounds = bounds.grow(BOUNDS_MARGIN)

	return bounds


func _calculate_overview_zoom(bounds: Rect2) -> Vector2:
	## Given the level bounds, compute the zoom factor that fits the entire
	## bounds within the viewport.
	##
	## Camera2D zoom works like magnification:
	##   - zoom = 2 means everything looks 2x bigger (you see less of the world)
	##   - zoom = 0.5 means everything looks half-size (you see more of the world)
	##
	## To fit `bounds` on screen, we need:
	##   zoom = viewport_size / bounds_size
	## Then take the smaller of width/height ratios so nothing gets clipped.
	##
	## IMPORTANT: The Player scene is instanced at scale 0.25 in levels, and
	## the Camera2D inherits that scale. But zoom is applied independently of
	## the node's scale — it directly controls how many world-pixels map to
	## screen-pixels. So we compute in world coordinates and it just works.

	var viewport_size: Vector2 = get_viewport_rect().size  # 1280x720

	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return _default_zoom

	var zoom_x: float = viewport_size.x / bounds.size.x
	var zoom_y: float = viewport_size.y / bounds.size.y

	# Use the smaller ratio so the entire level fits (letterboxing one axis if needed)
	var fit_zoom: float = min(zoom_x, zoom_y)

	# Don't zoom in more than the default (no point zooming in during overview)
	fit_zoom = min(fit_zoom, _default_zoom.x)

	# Don't zoom out to absurdly small levels
	fit_zoom = max(fit_zoom, MIN_ZOOM)

	# Camera2D zoom is uniform (same X and Y)
	return Vector2(fit_zoom, fit_zoom)
