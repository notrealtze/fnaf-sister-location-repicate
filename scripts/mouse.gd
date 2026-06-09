extends Node

@export var cursor_texture_path: String = "res://images/cursor.png"
@export var cursor_size: Vector2 = Vector2(32, 32)
@export var drag_sensitivity: float = 1.5
@export var target_node_path: NodePath
@export var overscale: float = 1.3

var _cursor_texture: Texture2D
var _cursor_sprite: Sprite2D
var _target_sprite: Sprite2D
var _cursor_pos: Vector2
var _last_touch_pos: Vector2 = Vector2.ZERO
var _is_touching: bool = false
var _touch_index: int = -1
var _is_pc: bool = false
var _screen_size: Vector2
var _max_offset: Vector2
var movement_locked: bool = false:
	set(value):
		if movement_locked == value:
			return
		movement_locked = value
		if not value:
			_pos_at_unlock = get_viewport().get_mouse_position() if _is_pc else _cursor_pos
			_waiting_for_move = true

var _pos_at_unlock: Vector2 = Vector2.ZERO
var _waiting_for_move: bool = false

func _get_resized_cursor_texture() -> ImageTexture:
	var img := _cursor_texture.get_image()
	img.resize(64, 64, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

func _ready() -> void:
	_is_pc = OS.has_feature("pc")
	_screen_size = get_viewport().get_visible_rect().size

	if target_node_path:
		_target_sprite = get_node(target_node_path) as Sprite2D

	if _target_sprite == null:
		push_error("CameraController: Target node not found or is not a Sprite2D.")
		return

	if _target_sprite.texture == null:
		push_error("CameraController: Target Sprite2D has no texture assigned.")
		return

	_cursor_texture = load(cursor_texture_path) as Texture2D
	if _cursor_texture == null:
		push_error("CameraController: Cursor texture not found at path: %s" % cursor_texture_path)
		return

	var oversized: Vector2 = _screen_size * overscale
	_max_offset = (oversized - _screen_size) / 2.0
	_target_sprite.centered = true
	_target_sprite.position = _screen_size / 2.0
	_target_sprite.scale = oversized / _target_sprite.texture.get_size()

	if _is_pc:
		Input.set_custom_mouse_cursor(_get_resized_cursor_texture(), Input.CURSOR_ARROW, Vector2.ZERO)
		get_viewport().connect("focus_entered", _on_focus_entered)
		get_viewport().connect("focus_exited", _on_focus_exited)
		_lock_cursor()
		return

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_cursor_sprite = Sprite2D.new()
	_cursor_sprite.texture = _cursor_texture
	_cursor_sprite.centered = false
	_cursor_sprite.scale = cursor_size / _cursor_texture.get_size()
	_cursor_sprite.z_index = 100
	_cursor_pos = _screen_size / 2.0
	_cursor_sprite.position = _cursor_pos
	call_deferred("_add_cursor_to_scene")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_on_focus_entered()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_on_focus_exited()

func _lock_cursor() -> void:
	var saved_pos: Vector2 = get_viewport().get_mouse_position()
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	Input.set_custom_mouse_cursor(_get_resized_cursor_texture(), Input.CURSOR_ARROW, Vector2.ZERO)
	DisplayServer.warp_mouse(saved_pos)

func _on_focus_entered() -> void:
	_lock_cursor()

func _on_focus_exited() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _add_cursor_to_scene() -> void:
	get_tree().current_scene.add_child(_cursor_sprite)

func _process(_delta: float) -> void:
	if _target_sprite == null:
		return
	if movement_locked:
		if not _is_pc and _cursor_sprite != null:
			_cursor_sprite.position = _cursor_pos
		return

	if _is_pc:
		var mouse_pos := get_viewport().get_mouse_position()
		if _waiting_for_move:
			if mouse_pos.distance_to(_pos_at_unlock) > 2.0:
				_waiting_for_move = false
			else:
				return
		_move_target(mouse_pos)
	elif _cursor_sprite != null:
		if _waiting_for_move:
			if _cursor_pos.distance_to(_pos_at_unlock) > 2.0:
				_waiting_for_move = false
			else:
				return
		_move_target(_cursor_pos)

func _move_target(pos: Vector2) -> void:
	var half: Vector2 = _screen_size / 2.0
	var norm: Vector2 = (pos - half) / half
	norm = norm.clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
	_target_sprite.position = half + (-norm * _max_offset)

func _input(event: InputEvent) -> void:
	if _is_pc:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			var corrected := InputEventMouseButton.new()
			corrected.button_index = mb.button_index
			corrected.pressed = mb.pressed
			corrected.position = mb.position
			corrected.global_position = mb.global_position
			corrected.double_click = mb.double_click
			get_viewport().push_input(corrected)
		return

	if _cursor_sprite == null:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1:
			_touch_index = touch.index
			_is_touching = true
			_last_touch_pos = touch.position
		elif not touch.pressed and touch.index == _touch_index:
			_is_touching = false
			_touch_index = -1

	elif event is InputEventScreenDrag and _is_touching:
		var drag := event as InputEventScreenDrag
		if drag.index != _touch_index:
			return
		var delta: Vector2 = drag.position - _last_touch_pos
		_last_touch_pos = drag.position
		_cursor_pos += delta * drag_sensitivity
		_cursor_pos = _cursor_pos.clamp(Vector2.ZERO, _screen_size)
		_cursor_sprite.position = _cursor_pos

func _simulate_mouse(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	Input.parse_input_event(motion)
