extends Sprite2D

@export var frames_folder: String = "res://animations/"
@export var fps: float = 24.0
@export var overscale: float = 1.3
@export var camera_controller_path: NodePath
@export var debug_prints: bool = false
@export var ambient_manager: NodePath

@export_group("Door Hitbox")
@export var debug_door_hitbox: bool = false:
	set(v):
		debug_door_hitbox = v
		if is_inside_tree():
			_update_door_debug_overlay()
@export_range(-1000.0, 1000.0, 1.0) var door_hitbox_offset_x: float = 0.0:
	set(v):
		door_hitbox_offset_x = v
		if is_inside_tree():
			_recompute_door_rect()
@export_range(-1000.0, 1000.0, 1.0) var door_hitbox_offset_y: float = 0.0:
	set(v):
		door_hitbox_offset_y = v
		if is_inside_tree():
			_recompute_door_rect()
@export_range(0.0, 2000.0, 1.0) var door_hitbox_width: float = 200.0:
	set(v):
		door_hitbox_width = v
		if is_inside_tree():
			_recompute_door_rect()
@export_range(0.0, 2000.0, 1.0) var door_hitbox_height: float = 400.0:
	set(v):
		door_hitbox_height = v
		if is_inside_tree():
			_recompute_door_rect()

@export_group("Crawl")
@export var crawl_hold_threshold: float = 0.4
@export var crawl_sound: AudioStream = null

@export_group("Vent")
@export var vent_fps: float = 12.0
@export var vent_entry_sound: AudioStream = null
@export var vent_exit_sound: AudioStream = null

@export_group("Destination")
@export var destination_crawl_time: float = 5.0
@export var destination_fade_out_duration: float = 2.0
@export var destination_fade_in_duration: float = 1.5
@export var shift_text_fps: float = 12.0
@export var night_won_sound: AudioStream = null

@export_group("Fade Transitions")
@export var fade_out_duration: float = 2.5
@export var fade_in_duration: float = 1.5

@export_group("Control Module")
@export var control_module_fps: float = 24.0
@export var control_module_sound: AudioStream = null

@export_group("")

var _frames: Array[Texture2D] = []
var _current_frame: int = 0
var _timer: float = 0.0
var _screen_size: Vector2
var _frozen: bool = false

var _door_frames: Array[Texture2D] = []
var _door_frame_index: int = 0
var _door_timer: float = 0.0
var _door_fps: float = 24.0
var _playing_door: bool = false

var _black_bg: ColorRect = null

var _door_rect: Rect2 = Rect2()
var _door_hitbox_active: bool = false
var _door_debug_overlay: ColorRect = null

var _fade_overlay: ColorRect = null
var _fading_out: bool = false
var _fading_in: bool = false
var _fade_alpha: float = 0.0

var _touch_holding: bool = false
var _touch_elapsed: float = 0.0

var _crawling: bool = false
var _crawl_sfx: AudioStreamPlayer = null
var _vent_entry_sfx: AudioStreamPlayer = null
var _vent_exit_sfx: AudioStreamPlayer = null
var _in_vent: bool = false

var _vent_frames: Array[Texture2D] = []
var _vent_frame_index: int = 0
var _vent_timer: float = 0.0
var _playing_vent: bool = false

var _camera_controller: Node = null
var _ambient: Node = null

var _crawl_elapsed: float = 0.0
var _destination_triggered: bool = false

var _control_module_frames: Array[Texture2D] = []
var _control_module_frame_index: int = 0
var _control_module_timer: float = 0.0
var _playing_control_module: bool = false
var _control_module_sfx: AudioStreamPlayer = null

var _elevator_texture: Texture2D = null
var _venting_out: bool = false
var _venting_in: bool = false
var _vent_exit_fade_alpha: float = 0.0

var _dest_transition: bool = false
var _dest_fade_out: bool = false
var _dest_fade_in: bool = false
var _dest_fade_alpha: float = 0.0

func _ready() -> void:
	add_to_group("background_animator")
	_screen_size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	centered = true
	position = _screen_size / 2.0
	z_index = 0

	if camera_controller_path:
		_camera_controller = get_node(camera_controller_path)

	if ambient_manager:
		_ambient = get_node(ambient_manager)

	_build_black_bg()
	_build_fade_overlay()
	_build_crawl_sfx()
	_build_vent_entry_sfx()
	_build_vent_exit_sfx()
	_build_control_module_sfx()
	_load_frames()
	_load_vent_frames()
	_load_control_module_frames()
	_recompute_door_rect()
	_update_door_debug_overlay()

func _get_scene_root() -> Node:
	return get_tree().root.get_child(get_tree().root.get_child_count() - 1)

func _build_black_bg() -> void:
	_black_bg = ColorRect.new()
	_black_bg.color = Color(0.0, 0.0, 0.0, 1.0)
	_black_bg.z_index = -1
	_black_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_get_scene_root().add_child.call_deferred(_black_bg)
	_size_black_bg.call_deferred()

func _size_black_bg() -> void:
	if _black_bg == null:
		return
	_black_bg.position = Vector2.ZERO
	_black_bg.size = _screen_size

func _build_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_overlay.z_index = 500
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.position = Vector2.ZERO
	_fade_overlay.size = _screen_size
	_get_scene_root().add_child.call_deferred(_fade_overlay)

func _build_crawl_sfx() -> void:
	_crawl_sfx = AudioStreamPlayer.new()
	if crawl_sound != null:
		var ogg := crawl_sound as AudioStreamOggVorbis
		if ogg != null:
			ogg.loop = true
		_crawl_sfx.stream = crawl_sound
		_crawl_sfx.volume_db = 0.0
	else:
		push_error("BackgroundAnimator: crawl_sound not assigned in Inspector.")
	_get_scene_root().add_child.call_deferred(_crawl_sfx)

func _build_vent_entry_sfx() -> void:
	_vent_entry_sfx = AudioStreamPlayer.new()
	if vent_entry_sound != null:
		_vent_entry_sfx.stream = vent_entry_sound
		_vent_entry_sfx.volume_db = 0.0
	else:
		push_error("BackgroundAnimator: vent_entry_sound not assigned in Inspector.")
	_get_scene_root().add_child.call_deferred(_vent_entry_sfx)

func _build_vent_exit_sfx() -> void:
	_vent_exit_sfx = AudioStreamPlayer.new()
	if vent_exit_sound != null:
		_vent_exit_sfx.stream = vent_exit_sound
		_vent_exit_sfx.volume_db = 0.0
	else:
		push_error("BackgroundAnimator: vent_exit_sound not assigned in Inspector.")
	_get_scene_root().add_child.call_deferred(_vent_exit_sfx)

func _build_control_module_sfx() -> void:
	_control_module_sfx = AudioStreamPlayer.new()
	if control_module_sound != null:
		var ogg := control_module_sound as AudioStreamOggVorbis
		if ogg != null:
			ogg.loop = true
		_control_module_sfx.stream = control_module_sound
		_control_module_sfx.volume_db = 0.0
	else:
		var path := "res://sounds/HandUnitControlModule.ogg"
		if ResourceLoader.exists(path):
			var res := load(path) as AudioStream
			if res != null:
				var ogg_loaded := res as AudioStreamOggVorbis
				if ogg_loaded != null:
					ogg_loaded.loop = true
				_control_module_sfx.stream = res
				_control_module_sfx.volume_db = 0.0
		if _control_module_sfx.stream == null:
			push_error("BackgroundAnimator: control_module_sound not assigned and default file not found.")
	_get_scene_root().add_child.call_deferred(_control_module_sfx)

func _load_control_module_frames() -> void:
	var folder := "res://ControlModule/"
	_control_module_frames.clear()
	var i := 1
	while true:
		var path := folder + ("frame_%04d.png" % i)
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				_control_module_frames.append(tex)
			i += 1
		else:
			break
	if _control_module_frames.is_empty():
		push_error("BackgroundAnimator: No ControlModule frames found in res://ControlModule/")
	elif debug_prints:
		print("[BackgroundAnimator] Loaded ", _control_module_frames.size(), " ControlModule frames.")

func _mute_elevator_ambient() -> void:
	if _ambient != null and _ambient.has_method("fade_out_and_mute"):
		_ambient.fade_out_and_mute()

func _stop_all_audio() -> void:
	for node in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		var player := node as AudioStreamPlayer
		if player != null and player.playing:
			player.stop()

func _on_viewport_size_changed() -> void:
	_screen_size = get_viewport().get_visible_rect().size
	position = _screen_size / 2.0
	_apply_scale()
	_size_black_bg()
	if _fade_overlay != null:
		_fade_overlay.size = _screen_size
	_recompute_door_rect()

func _apply_scale() -> void:
	if texture == null:
		return
	var oversized: Vector2 = _screen_size * overscale
	scale = oversized / texture.get_size()

func _load_frames() -> void:
	var frame_files: Array[String] = []
	var i := 1
	while true:
		var path := frames_folder.path_join("frame_%04d.png" % i)
		if ResourceLoader.exists(path):
			frame_files.append("frame_%04d.png" % i)
			i += 1
		else:
			break

	if frame_files.is_empty():
		push_error("BackgroundAnimator: No frame_XXXX.png files found in: %s" % frames_folder)
		return

	for file in frame_files:
		var tex := load(frames_folder.path_join(file)) as Texture2D
		if tex != null:
			_frames.append(tex)

	if not _frames.is_empty():
		texture = _frames[0]
		_apply_scale()

func _load_vent_frames() -> void:
	var folder := "res://animations/Vents/"
	_vent_frames.clear()
	for i in range(1, 16):
		var path := folder + ("frame_%04d.png" % i)
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				_vent_frames.append(tex)
	if _vent_frames.is_empty():
		push_error("BackgroundAnimator: No vent frames found in res://animations/Vents/")

func _recompute_door_rect() -> void:
	if texture == null:
		return
	var rendered_size: Vector2 = texture.get_size() * scale
	var top_left: Vector2 = position - rendered_size / 2.0
	var w: float = door_hitbox_width
	var h: float = door_hitbox_height
	_door_rect = Rect2(
		Vector2(top_left.x + (rendered_size.x * 0.5) - (w / 2.0) + door_hitbox_offset_x,
				top_left.y + (rendered_size.y * 0.5) - (h / 2.0) + door_hitbox_offset_y),
		Vector2(w, h)
	)
	_update_door_debug_overlay()

func _update_door_debug_overlay() -> void:
	if not is_inside_tree():
		return
	if not debug_door_hitbox:
		if _door_debug_overlay != null:
			_door_debug_overlay.visible = false
		return
	if _door_debug_overlay == null:
		_door_debug_overlay = ColorRect.new()
		_door_debug_overlay.z_index = 200
		_get_scene_root().add_child.call_deferred(_door_debug_overlay)
	_door_debug_overlay.color = Color(0.0, 0.5, 1.0, 0.3)
	_door_debug_overlay.position = _door_rect.position
	_door_debug_overlay.size = _door_rect.size
	_door_debug_overlay.visible = true

func freeze_on_elevator(elevator_texture: Texture2D) -> void:
	_mute_elevator_ambient()
	_elevator_texture = elevator_texture
	_frozen = true
	texture = elevator_texture
	_apply_scale()
	_recompute_door_rect()

func play_door_anim(frames: Array[Texture2D], door_fps: float) -> void:
	if frames.is_empty():
		return
	_door_frames = frames
	_door_frame_index = 0
	_door_timer = 0.0
	_door_fps = door_fps
	_playing_door = true
	_frozen = true
	texture = _door_frames[0]
	_apply_scale()

func activate_door_hitbox() -> void:
	_door_hitbox_active = true
	_recompute_door_rect()
	_update_door_debug_overlay()

func deactivate_door_hitbox() -> void:
	_door_hitbox_active = false
	_update_door_debug_overlay()

func play_vent() -> void:
	if _vent_frames.is_empty():
		return
	_mute_elevator_ambient()
	if _vent_entry_sfx != null and _vent_entry_sfx.is_inside_tree():
		_vent_entry_sfx.play()
	_in_vent = true
	_vent_frame_index = 0
	_vent_timer = 0.0
	_playing_vent = true
	_frozen = true
	_crawl_elapsed = 0.0
	_destination_triggered = false
	texture = _vent_frames[0]
	_apply_scale()

func stop_vent() -> void:
	if not _in_vent and not _playing_vent and not _playing_control_module:
		return
	if _venting_out or _venting_in or _dest_transition:
		return
	_stop_crawl()
	if _crawl_sfx != null and _crawl_sfx.playing:
		_crawl_sfx.stop()
	if _control_module_sfx != null and _control_module_sfx.playing:
		_control_module_sfx.stop()
	_playing_control_module = false
	_playing_vent = false
	_in_vent = false
	_venting_out = true
	_vent_exit_fade_alpha = 0.0
	if _vent_exit_sfx != null and _vent_exit_sfx.is_inside_tree():
		_vent_exit_sfx.play()
	if _fade_overlay != null:
		_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)

func _start_fade_to_black() -> void:
	_fading_out = true
	_fading_in = false
	_fade_alpha = 0.0
	if _fade_overlay != null:
		_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)

func _trigger_destination() -> void:
	if _destination_triggered:
		return
	_destination_triggered = true
	_dest_transition = true
	_dest_fade_out = true
	_dest_fade_in = false
	_dest_fade_alpha = 0.0
	if _fade_overlay != null:
		_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)

func _input(event: InputEvent) -> void:
	if _playing_control_module or _venting_out or _venting_in or _dest_transition:
		return

	var clicked := false
	if event is InputEventScreenTouch and event.pressed:
		clicked = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked = true

	if clicked:
		var cursor_pos := Vector2.ZERO
		if _camera_controller:
			cursor_pos = _camera_controller.get("_cursor_pos")
		else:
			cursor_pos = get_viewport().get_mouse_position()

		var transformed_pos := get_viewport().get_canvas_transform().affine_inverse() * cursor_pos

		if _door_hitbox_active and _door_rect.has_point(transformed_pos):
			_door_hitbox_active = false
			if _door_debug_overlay != null:
				_door_debug_overlay.visible = false
			_start_fade_to_black()

	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			_touch_holding = true
			_touch_elapsed = 0.0
		else:
			_touch_holding = false
			_stop_crawl()

	elif event is InputEventKey:
		if event.keycode == KEY_W:
			if event.pressed and not event.echo:
				_start_crawl()
			elif not event.pressed:
				_stop_crawl()

func _start_crawl() -> void:
	if _crawling or not _in_vent:
		return
	_crawling = true
	if _crawl_sfx != null and _crawl_sfx.is_inside_tree():
		_crawl_sfx.play()

func _stop_crawl() -> void:
	if not _crawling:
		return
	_crawling = false
	_crawl_elapsed = 0.0
	if _crawl_sfx != null and _crawl_sfx.is_inside_tree():
		_crawl_sfx.stop()

func _process(delta: float) -> void:
	if _venting_out:
		if _fade_overlay != null:
			_vent_exit_fade_alpha = move_toward(_vent_exit_fade_alpha, 1.0, delta / fade_out_duration)
			_fade_overlay.color = Color(0.0, 0.0, 0.0, _vent_exit_fade_alpha)
			if _vent_exit_fade_alpha >= 1.0:
				_venting_out = false
				_venting_in = true
				if _elevator_texture != null:
					texture = _elevator_texture
					_apply_scale()
				_frozen = true
				_door_hitbox_active = true
				_recompute_door_rect()
				_update_door_debug_overlay()
		return

	if _venting_in:
		if _fade_overlay != null:
			_vent_exit_fade_alpha = move_toward(_vent_exit_fade_alpha, 0.0, delta / fade_in_duration)
			_fade_overlay.color = Color(0.0, 0.0, 0.0, _vent_exit_fade_alpha)
			if _vent_exit_fade_alpha <= 0.0:
				_venting_in = false
		return

	if _dest_transition:
		if _dest_fade_out:
			if _fade_overlay != null:
				_dest_fade_alpha = move_toward(_dest_fade_alpha, 1.0, delta / destination_fade_out_duration)
				_fade_overlay.color = Color(0.0, 0.0, 0.0, _dest_fade_alpha)
				if _dest_fade_alpha >= 1.0:
					_dest_fade_out = false
					_dest_fade_in = true
					_stop_crawl()
					if _crawl_sfx != null and _crawl_sfx.playing:
						_crawl_sfx.stop()
					_playing_control_module = true
					_control_module_frame_index = 0
					_control_module_timer = 0.0
					if _control_module_sfx != null and _control_module_sfx.is_inside_tree():
						_control_module_sfx.play()
					if not _control_module_frames.is_empty():
						texture = _control_module_frames[0]
						_apply_scale()
		elif _dest_fade_in:
			if _fade_overlay != null:
				_dest_fade_alpha = move_toward(_dest_fade_alpha, 0.0, delta / destination_fade_in_duration)
				_fade_overlay.color = Color(0.0, 0.0, 0.0, _dest_fade_alpha)
				if _dest_fade_alpha <= 0.0:
					_dest_fade_in = false
					_dest_transition = false

	if _playing_control_module:
		if _control_module_frames.is_empty():
			return
		_control_module_timer += delta
		var interval: float = 1.0 / control_module_fps
		while _control_module_timer >= interval:
			_control_module_timer -= interval
			_control_module_frame_index += 1
			if _control_module_frame_index >= _control_module_frames.size():
				_control_module_frame_index = 0
		texture = _control_module_frames[_control_module_frame_index]
		_apply_scale()
		return

	if _door_hitbox_active or debug_door_hitbox:
		_recompute_door_rect()

	if _touch_holding:
		_touch_elapsed += delta
		if _touch_elapsed >= crawl_hold_threshold:
			_start_crawl()

	if _fading_out and _fade_overlay != null:
		_fade_alpha = move_toward(_fade_alpha, 1.0, delta / fade_out_duration)
		_fade_overlay.color = Color(0.0, 0.0, 0.0, _fade_alpha)
		if _fade_alpha >= 1.0:
			_fading_out = false
			play_vent()
			_fading_in = true

	if _fading_in and _fade_overlay != null:
		_fade_alpha = move_toward(_fade_alpha, 0.0, delta / fade_in_duration)
		_fade_overlay.color = Color(0.0, 0.0, 0.0, _fade_alpha)
		if _fade_alpha <= 0.0:
			_fading_in = false

	if _playing_vent:
		if _crawling:
			_crawl_elapsed += delta
			if _crawl_elapsed >= destination_crawl_time and not _destination_triggered:
				_trigger_destination()
			_vent_timer += delta
			var interval: float = 1.0 / vent_fps
			while _vent_timer >= interval:
				_vent_timer -= interval
				_vent_frame_index += 1
				if _vent_frame_index >= _vent_frames.size():
					_vent_frame_index = 0
			texture = _vent_frames[_vent_frame_index]
			_apply_scale()
		return

	if _playing_door:
		_door_timer += delta
		while _door_timer >= 1.0 / _door_fps:
			_door_timer -= 1.0 / _door_fps
			_door_frame_index += 1
			if _door_frame_index >= _door_frames.size():
				_door_frame_index = _door_frames.size() - 1
				_playing_door = false
				activate_door_hitbox()
				break
		texture = _door_frames[_door_frame_index]
		_apply_scale()
		return

	if _frozen or _frames.is_empty():
		return
	_timer += delta
	if _timer >= 1.0 / fps:
		_timer = 0.0
		_current_frame = (_current_frame + 1) % _frames.size()
		texture = _frames[_current_frame]

# test