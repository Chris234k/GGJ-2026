extends Control
## Pause Screen - Overlay shown when the player presses ESC during gameplay.
## Freezes the scene tree while remaining responsive itself (PROCESS_MODE_ALWAYS).
## Emits signals for game.gd to handle resume/quit logic.
##
## Has three views that swap in-place within the same Content VBox:
##   1. Main menu   — Resume, Controls, Quit buttons
##   2. Confirming  — "Quit to Menu?" with [Y]/[N]
##   3. Controls    — list of all keybindings
##
## Keyboard controls:
##   ESC        — resume (or go back from sub-views)
##   Up/Down    — navigate buttons
##   Enter      — activate focused button
##   Q          — quit confirmation
##   C          — controls view
##   Y/N        — confirm/cancel quit

signal resume_requested
signal quit_requested

# --- Which sub-view is active ---
enum View { MAIN, CONFIRMING, CONTROLS }
var _current_view: View = View.MAIN

# --- Node refs ---
@onready var title_label: RichTextLabel = $Content/Title
@onready var resume_button: Button = $Content/ResumeButton
@onready var controls_button: Button = $Content/ControlsButton
@onready var quit_button: Button = $Content/QuitButton
@onready var confirm_hint: RichTextLabel = $Content/ConfirmHint
@onready var controls_list: RichTextLabel = $Content/ControlsList
@onready var back_hint: RichTextLabel = $Content/BackHint

## Whether the pause screen is allowed to open. Set to true by game.gd
## only during PLAYING state so ESC does nothing on menu/end screens.
var can_pause: bool = false

func _ready() -> void:
	# PROCESS_MODE_ALWAYS lets this node keep receiving input and processing
	# even when the rest of the scene tree is paused via get_tree().paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible and not can_pause:
		return

	# --- ESC: resume, or go back from sub-views ---
	if event.is_action_pressed("pause"):
		if _current_view != View.MAIN:
			_set_view(View.MAIN)
		elif visible:
			resume_requested.emit()
		elif can_pause:
			_pause()
		get_viewport().set_input_as_handled()
		return

	# Everything below only applies when the pause screen is visible.
	if not visible:
		return

	if not event is InputEventKey or not event.pressed:
		return

	match _current_view:
		View.CONFIRMING:
			if event.keycode == KEY_Y:
				_set_view(View.MAIN)
				quit_requested.emit()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_N:
				_set_view(View.MAIN)
				get_viewport().set_input_as_handled()

		View.CONTROLS:
			# C goes back (ESC is already handled above via the "pause" action)
			if event.keycode == KEY_C:
				_set_view(View.MAIN)
				get_viewport().set_input_as_handled()

		View.MAIN:
			if event.keycode == KEY_Q:
				_set_view(View.CONFIRMING)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_C:
				_set_view(View.CONTROLS)
				get_viewport().set_input_as_handled()

## Pause the game and show the overlay. Gives initial focus to the Resume
## button so the player can immediately use arrow keys to navigate.
func _pause() -> void:
	_set_view(View.MAIN)
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()

## Called by game.gd when it handles our resume_requested signal.
func unpause() -> void:
	get_tree().paused = false
	_set_view(View.MAIN)
	visible = false

## Switch between the three sub-views by toggling visibility of children
## and updating the title text.
func _set_view(view: View) -> void:
	_current_view = view

	# Hide everything first, then show what's needed.
	resume_button.visible = false
	controls_button.visible = false
	quit_button.visible = false
	confirm_hint.visible = false
	controls_list.visible = false
	back_hint.visible = false

	match view:
		View.MAIN:
			title_label.text = "[center][color=#00ff66][font_size=36]PAUSED[/font_size][/color][/center]"
			resume_button.visible = true
			controls_button.visible = true
			quit_button.visible = true
			resume_button.grab_focus()

		View.CONFIRMING:
			title_label.text = "[center][color=#00ff66][font_size=36]Quit to Menu?[/font_size][/color][/center]"
			confirm_hint.visible = true

		View.CONTROLS:
			title_label.text = "[center][color=#00ff66][font_size=36]CONTROLS[/font_size][/color][/center]"
			controls_list.visible = true
			back_hint.visible = true

func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_controls_pressed() -> void:
	_set_view(View.CONTROLS)

func _on_quit_pressed() -> void:
	_set_view(View.CONFIRMING)
