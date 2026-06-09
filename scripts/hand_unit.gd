extends Sprite2D

@export var voice_unit_folder: String = "res://VoiceUnit/"
@export var fps: float = 24.0
@export var intro_delay: float = 1.0
@export var overscale: float = 1.8
@export var camera_controller_path: NodePath
@export var caption_manager_path: NodePath
@export var debug_hitbox: bool = false
@export var debug_prints: bool = false
@export_range(1, 6, 1) var current_night: int = 1:
	set(v):
		current_night = v
		if _night_label != null:
			_night_label.text = "Night " + str(current_night)
@export var night_font: FontFile = null
@export var dark_elevator_texture: Texture2D = null

@export_group("Keypad Position")
@export_range(-1000.0, 1000.0, 1.0) var keypad_offset_x: float = 0.0:
	set(v):
		keypad_offset_x = v
		_apply_keypad_position()
@export_range(-1000.0, 1000.0, 1.0) var keypad_offset_y: float = 0.0:
	set(v):
		keypad_offset_y = v
		_apply_keypad_position()

@export_group("Keypad Hitbox")
@export_range(-1000.0, 1000.0, 1.0) var hitbox_offset_x: float = 0.0:
	set(v):
		hitbox_offset_x = v
		_recompute_keypad_rect()
@export_range(-1000.0, 1000.0, 1.0) var hitbox_offset_y: float = -10.0:
	set(v):
		hitbox_offset_y = v
		_recompute_keypad_rect()
@export_range(0.0, 2000.0, 1.0) var hitbox_width: float = 0.0:
	set(v):
		hitbox_width = v
		_recompute_keypad_rect()
@export_range(0.0, 2000.0, 1.0) var hitbox_height: float = 0.0:
	set(v):
		hitbox_height = v
		_recompute_keypad_rect()

@export_group("Red Button Hitbox")
@export_range(-1000.0, 1000.0, 1.0) var red_button_offset_x: float = 0.0:
	set(v):
		red_button_offset_x = v
		_recompute_red_button_rect()
@export_range(-1000.0, 1000.0, 1.0) var red_button_offset_y: float = 0.0:
	set(v):
		red_button_offset_y = v
		_recompute_red_button_rect()
@export_range(0.0, 2000.0, 1.0) var red_button_width: float = 80.0:
	set(v):
		red_button_width = v
		_recompute_red_button_rect()
@export_range(0.0, 2000.0, 1.0) var red_button_height: float = 80.0:
	set(v):
		red_button_height = v
		_recompute_red_button_rect()

@export_group("Buzzer")
@export var buzzer_interval_min: float = 8.0
@export var buzzer_interval_max: float = 20.0

@export_group("")

enum State {
	WAITING_INTRO,
	PLAYING_HAND_UNIT,
	PLAYING_OPEN_ANIM,
	PLAYING_ENTER_USERNAME,
	WAITING_KEYPAD_PRESS,
	PLAYING_ERROR_USERNAME,
	PLAYING_EGGS_BENEDICT,
	PLAYING_CLOSE_ANIM,
	WAITING_NIGHT_LABEL,
	FADING_IN_NIGHT_LABEL,
	HOLDING_NIGHT_LABEL,
	FADING_OUT_NIGHT_LABEL,
	SHOWING_ELEVATOR,
	PLAYING_RED_BUTTON_HINT,
	WAITING_RED_BUTTON,
	PLAYING_DOOR_ANIM,
	DONE
}

const CAPTION_HAND_UNIT := "[center][wave amp=5 freq=2][color=#e8e8e8]Welcome to the first day of your exciting new career! Whether you were approached at a job fair, read our ad at Screws, Bolts, and Hairpins, or if this is the result of a dare, we welcome you. I will be your personal guide to help you get started. I'm a model 5 of the Handyman's Robotics and Unit-Repair System, but you can call me Hand-Unit. Your new career promises challenge, intrigue and endless janitorial opportunities.[/color][/wave][/center]"
const CAPTION_ENTER_USERNAME := "[center][shake rate=8 level=2][color=#b8ffb8]Please enter your name as seen above the keypad. This cannot be changed later so please be careful.[/color][/shake][/center]"
const CAPTION_ERROR_USERNAME := "[center][color=#ffb8b8]It seems that you had some trouble with the keypad. I see what you were trying to type, and I will auto-correct it for you. One moment. Welcome:[/color][/center]"
const CAPTION_EGGS_BENEDICT := "[center][pulse color=#ffffff period=1.0][b][color=#ffffff]Eggs Benedict.[/color][/b][/pulse][/center]"
const CAPTION_RED_BUTTON := "[center][tornado radius=3 freq=3][color=#ff8080]You can now open the elevator using that bright, red and obvious button. Let's get to work![/color][/tornado][/center]"

var _screen_size: Vector2
var _audio_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _sfx_finished: bool = false
var _intro_elapsed: float = 0.0
var _state: State = State.WAITING_INTRO

var _open_frames: Array[Texture2D] = []
var _loop_frames: Array[Texture2D] = []
var _close_frames: Array[Texture2D] = []
var _current_frames: Array[Texture2D] = []
var _door_frames: Array[Texture2D] = []
var _anim_frame_index: int = 0
var _anim_timer: float = 0.0
var _reference_size: Vector2 = Vector2.ZERO

var _keypad_active: bool = false
var _keypad_press_handled: bool = false
var _camera_controller: Node
var _keypad_rect: Rect2 = Rect2()
var _debug_overlay: ColorRect
var _debug_red_overlay: ColorRect

var _red_button_rect: Rect2 = Rect2()
var _red_button_active: bool = false
var _red_button_handled: bool = false

var _night_label: Label
var _night_label_timer: float = 0.0
const _NIGHT_LABEL_PRE_DELAY: float = 1.6
const _NIGHT_LABEL_FADE_IN_DURATION: float = 2.0
const _NIGHT_LABEL_FADE_OUT_DURATION: float = 1.5

var _buzzer_timer: float = 0.0
var _buzzer_interval: float = 0.0
var _buzzer_player: AudioStreamPlayer

var _caption_manager: Node = null

func _ready() -> void:
	_screen_size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	centered = true
	position = Vector2(_screen_size.x / 2.0 + keypad_offset_x, _screen_size.y * 0.75 + keypad_offset_y)
	z_index = 1
	visible = false

	voice_unit_folder = _sanitize_folder(voice_unit_folder)
	
	_load_all_frames()
	_door_frames = _load_door_frames()

	if debug_prints:
		print("[HandUnitAnimator] voice_unit_folder: ", voice_unit_folder)
	if camera_controller_path:
		_camera_controller = get_node(camera_controller_path)
	if caption_manager_path:
		_caption_manager = get_node(caption_manager_path)

	_audio_player = AudioStreamPlayer.new()
	_audio_player.finished.connect(_on_audio_finished)
	add_child(_audio_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.finished.connect(_on_sfx_finished)
	get_tree().current_scene.add_child.call_deferred(_sfx_player)

	_buzzer_player = AudioStreamPlayer.new()
	get_tree().current_scene.add_child.call_deferred(_buzzer_player)
	_reset_buzzer_interval()

	_build_night_label()

func _build_night_label() -> void:
	_night_label = Label.new()
	_night_label.z_index = 300
	_night_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_night_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_night_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_night_label.text = "Night " + str(current_night)

	var ls := LabelSettings.new()
	ls.font_size = 48
	ls.font_color = Color(0.627, 0.627, 0.627, 1.0)
	ls.shadow_color = Color(0.0, 0.0, 0.0, 0.75)
	ls.shadow_size = 4
	ls.shadow_offset = Vector2(2.0, 3.0)
	ls.outline_color = Color(0.0, 0.0, 0.0, 0.5)
	ls.outline_size = 2
	if night_font != null:
		ls.font = night_font
	else:
		var default_font := load("res://fonts/ArsenalSC-Regular.ttf") as FontFile
		if default_font != null:
			ls.font = default_font
	_night_label.label_settings = ls

	_night_label.set_anchors_preset(Control.PRESET_CENTER)
	_night_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_night_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_night_label.custom_minimum_size = Vector2(600.0, 100.0)

	get_tree().current_scene.add_child.call_deferred(_night_label)
	_center_night_label.call_deferred()

func _center_night_label() -> void:
	if _night_label == null:
		return
	_night_label.position = Vector2(
		_screen_size.x / 2.0 - _night_label.custom_minimum_size.x / 2.0,
		_screen_size.y / 2.0 - _night_label.custom_minimum_size.y / 2.0
	)

func _on_viewport_size_changed() -> void:
	_screen_size = get_viewport().get_visible_rect().size
	position = Vector2(_screen_size.x / 2.0 + keypad_offset_x, _screen_size.y * 0.75 + keypad_offset_y)
	_apply_scale()
	_recompute_keypad_rect()
	_recompute_red_button_rect()
	_center_night_label()

func _apply_keypad_position() -> void:
	position = Vector2(_screen_size.x / 2.0 + keypad_offset_x, _screen_size.y * 0.75 + keypad_offset_y)
	_recompute_keypad_rect()

func _apply_scale() -> void:
	if texture == null:
		return
	if _reference_size != Vector2.ZERO and texture.get_size() != Vector2.ZERO:
		var ratio: Vector2 = _reference_size / texture.get_size()
		scale = Vector2(overscale * ratio.x, overscale * ratio.y)
	else:
		scale = Vector2(overscale, overscale)

func _recompute_keypad_rect() -> void:
	if texture == null:
		return
	var s: Vector2 = texture.get_size() * scale
	var top_left: Vector2 = position - s / 2.0
	var w: float = hitbox_width if hitbox_width > 0.0 else s.x * 0.55
	var h: float = hitbox_height if hitbox_height > 0.0 else s.y * 0.6
	_keypad_rect = Rect2(
		top_left + Vector2(s.x * 0.35 + hitbox_offset_x, s.y * -0.05 + hitbox_offset_y),
		Vector2(w, h)
	)
	if debug_prints:
		print("[HandUnitAnimator] keypad_rect: ", _keypad_rect)
	_update_debug_overlay()

func _recompute_red_button_rect() -> void:
	if not is_inside_tree():
		return
	var bg := get_tree().get_first_node_in_group("background_animator") as Sprite2D
	var anchor := Vector2(_screen_size.x * 0.685, _screen_size.y * 0.45)
	if bg != null and bg.texture != null:
		var tex_size: Vector2 = bg.texture.get_size()
		var rendered_size: Vector2 = tex_size * bg.scale
		var top_left: Vector2 = bg.position - rendered_size / 2.0
		anchor = top_left + Vector2(rendered_size.x * 0.685, rendered_size.y * 0.45)
	var w: float = red_button_width
	var h: float = red_button_height
	_red_button_rect = Rect2(
		Vector2(anchor.x - w / 2.0 + red_button_offset_x, anchor.y - h / 2.0 + red_button_offset_y),
		Vector2(w, h)
	)
	if debug_prints:
		print("[HandUnitAnimator] red_button_rect: ", _red_button_rect)
	_update_red_debug_overlay()

func _update_debug_overlay() -> void:
	if not debug_hitbox:
		if _debug_overlay != null:
			_debug_overlay.visible = false
		return
	if _debug_overlay == null:
		_debug_overlay = ColorRect.new()
		_debug_overlay.z_index = 200
		get_tree().current_scene.add_child(_debug_overlay)
	_debug_overlay.color = Color(0.0, 1.0, 0.0, 0.25)
	_debug_overlay.position = _keypad_rect.position
	_debug_overlay.size = _keypad_rect.size
	_debug_overlay.visible = _keypad_active

func _update_red_debug_overlay() -> void:
	if not debug_hitbox:
		if _debug_red_overlay != null:
			_debug_red_overlay.visible = false
		return
	if _debug_red_overlay == null:
		_debug_red_overlay = ColorRect.new()
		_debug_red_overlay.z_index = 200
		get_tree().current_scene.add_child(_debug_red_overlay)
	_debug_red_overlay.color = Color(1.0, 0.0, 0.0, 0.25)
	_debug_red_overlay.position = _red_button_rect.position
	_debug_red_overlay.size = _red_button_rect.size
	_debug_red_overlay.visible = _red_button_active

func _sanitize_folder(folder: String) -> String:
	if not folder.begins_with("res://") and not folder.begins_with("user://"):
		folder = "res://" + folder.lstrip("/")
	if not folder.ends_with("/"):
		folder += "/"
	return folder

func _play_audio(file_name: String, caption: String = "") -> void:
	var path: String = voice_unit_folder + file_name
	var stream := load(path) as AudioStream
	if stream == null:
		push_error("HandUnitAnimator: Could not load audio: %s" % path)
		return
	_audio_player.stream = stream
	_audio_player.play()
	if _caption_manager != null and caption != "":
		_caption_manager.show_caption(caption, _audio_player)

func _play_sfx(file_name: String) -> void:
	if _sfx_player == null or not _sfx_player.is_inside_tree():
		push_error("HandUnitAnimator: _sfx_player not ready yet.")
		_sfx_finished = true
		return
	var path: String = "res://sounds/" + file_name
	var stream := load(path) as AudioStream
	if stream == null:
		push_error("HandUnitAnimator: Could not load sfx: %s" % path)
		_sfx_finished = true
		return
	_sfx_finished = false
	_sfx_player.stream = stream
	_sfx_player.play()

func _on_sfx_finished() -> void:
	_sfx_finished = true

func _reset_buzzer_interval() -> void:
	_buzzer_interval = randf_range(buzzer_interval_min, buzzer_interval_max)
	_buzzer_timer = 0.0

func _tick_buzzer(delta: float) -> void:
	if _buzzer_player == null or not _buzzer_player.is_inside_tree():
		return
	_buzzer_timer += delta
	if _buzzer_timer >= _buzzer_interval:
		_reset_buzzer_interval()
		var path: String = voice_unit_folder + "Buzzer.ogg"
		var stream := load(path) as AudioStream
		if stream != null:
			_buzzer_player.stream = stream
			_buzzer_player.play()
		else:
			push_error("HandUnitAnimator: Could not load Buzzer.ogg from: %s" % path)

func _load_frames_from_subfolder(subfolder: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var folder_path: String = voice_unit_folder + subfolder + "/"
	var start := 1
	for probe in range(1, 10000):
		if ResourceLoader.exists(folder_path + ("frame_%04d.png" % probe)):
			start = probe
			break
	var i := start
	while true:
		var path: String = folder_path + ("frame_%04d.png" % i)
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				frames.append(tex)
			i += 1
		else:
			break
	if frames.is_empty():
		push_error("HandUnitAnimator: No frames found in: %s" % folder_path)
	if debug_prints:
		print("[HandUnitAnimator] Loaded %d frames from %s (start=%d)" % [frames.size(), folder_path, start])
	return frames

func _load_all_frames() -> void:
	_open_frames = _load_frames_from_subfolder("OpenAnims")
	_loop_frames = _load_frames_from_subfolder("Anims")
	_close_frames = _load_frames_from_subfolder("CloseAnims")
	if not _loop_frames.is_empty():
		_reference_size = _loop_frames[0].get_size()

func _start_anim(frames: Array[Texture2D]) -> void:
	_current_frames = frames
	_anim_frame_index = 0
	_anim_timer = 0.0
	if not _current_frames.is_empty():
		texture = _current_frames[0]
	visible = true
	_apply_scale()
	_recompute_keypad_rect()

func _on_audio_finished() -> void:
	match _state:
		State.PLAYING_HAND_UNIT:
			_start_anim(_open_frames)
			_state = State.PLAYING_OPEN_ANIM
			if _camera_controller:
				_camera_controller.movement_locked = true
		State.PLAYING_ENTER_USERNAME:
			_state = State.WAITING_KEYPAD_PRESS
		State.PLAYING_ERROR_USERNAME:
			_state = State.PLAYING_EGGS_BENEDICT
			_play_audio("eggsBenedict.ogg", CAPTION_EGGS_BENEDICT)
		State.PLAYING_EGGS_BENEDICT:
			_start_anim(_close_frames)
			_state = State.PLAYING_CLOSE_ANIM
		State.PLAYING_RED_BUTTON_HINT:
			_red_button_active = true
			_red_button_handled = false
			_state = State.WAITING_RED_BUTTON
			_update_red_debug_overlay()

func _input(event: InputEvent) -> void:
	var clicked := false
	if event is InputEventScreenTouch and event.pressed:
		clicked = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked = true

	if not clicked:
		return

	var cursor_pos := Vector2.ZERO
	if event is InputEventMouseButton:
		cursor_pos = event.position
	elif event is InputEventScreenTouch:
		if _camera_controller:
			cursor_pos = _camera_controller.get("_cursor_pos")
		else:
			cursor_pos = event.position

	var transformed_pos := get_viewport().get_canvas_transform().affine_inverse() * cursor_pos

	if _state == State.WAITING_KEYPAD_PRESS and _keypad_active and not _keypad_press_handled:
		if _keypad_rect.has_point(transformed_pos):
			_keypad_press_handled = true
			_keypad_active = false
			_state = State.PLAYING_ERROR_USERNAME
			_play_audio("Error username.ogg", CAPTION_ERROR_USERNAME)
			if _debug_overlay != null:
				_debug_overlay.visible = false
			if debug_prints:
				print("[HandUnitAnimator] Keypad pressed.")

	if _state == State.WAITING_RED_BUTTON and _red_button_active and not _red_button_handled:
		if _red_button_rect.has_point(transformed_pos):
			_red_button_handled = true
			_red_button_active = false
			if _debug_red_overlay != null:
				_debug_red_overlay.visible = false
			_play_sfx("ClankDoorOpen.ogg")
			_state = State.PLAYING_DOOR_ANIM
			var bg := get_tree().get_first_node_in_group("background_animator")
			if bg != null:
				bg.play_door_anim(_door_frames, fps)
			if debug_prints:
				print("[HandUnitAnimator] Red button pressed, playing door anim.")

func _process_anim_playonce(delta: float) -> bool:
	if _current_frames.is_empty():
		return true
	_anim_timer += delta
	if _anim_timer >= 1.0 / fps:
		_anim_timer = 0.0
		_anim_frame_index += 1
		if _anim_frame_index >= _current_frames.size():
			_anim_frame_index = _current_frames.size() - 1
			texture = _current_frames[_anim_frame_index]
			return true
		texture = _current_frames[_anim_frame_index]
	return false

func _process_anim_loop(delta: float) -> void:
	if _current_frames.is_empty():
		return
	_anim_timer += delta
	if _anim_timer >= 1.0 / fps:
		_anim_timer = 0.0
		_anim_frame_index = (_anim_frame_index + 1) % _current_frames.size()
		texture = _current_frames[_anim_frame_index]

func _process(delta: float) -> void:
	match _state:
		State.WAITING_INTRO:
			_tick_buzzer(delta)
			_intro_elapsed += delta
			if _intro_elapsed >= intro_delay:
				_state = State.PLAYING_HAND_UNIT
				_play_audio("HandUnitNight1.ogg", CAPTION_HAND_UNIT)
		State.PLAYING_OPEN_ANIM:
			var done := _process_anim_playonce(delta)
			if done:
				_start_anim(_loop_frames)
				_keypad_active = true
				_state = State.PLAYING_ENTER_USERNAME
				_play_audio("EnterUsername.ogg", CAPTION_ENTER_USERNAME)
				_update_debug_overlay()
				if debug_prints:
					print("[HandUnitAnimator] OpenAnim done.")
		State.PLAYING_ENTER_USERNAME, State.WAITING_KEYPAD_PRESS, State.PLAYING_ERROR_USERNAME, State.PLAYING_EGGS_BENEDICT:
			_tick_buzzer(delta)
			_process_anim_loop(delta)
		State.PLAYING_CLOSE_ANIM:
			var done := _process_anim_playonce(delta)
			if done:
				_keypad_active = false
				visible = false
				if _debug_overlay != null:
					_debug_overlay.visible = false
				if _camera_controller:
					_camera_controller.movement_locked = false
				_state = State.WAITING_NIGHT_LABEL
				_night_label_timer = 0.0
				if debug_prints:
					print("[HandUnitAnimator] CloseAnim done.")
		State.WAITING_NIGHT_LABEL:
			_night_label_timer += delta
			if _night_label_timer >= _NIGHT_LABEL_PRE_DELAY:
				_night_label_timer = 0.0
				_state = State.FADING_IN_NIGHT_LABEL
				_play_sfx("StartNight.ogg")
		State.FADING_IN_NIGHT_LABEL:
			_night_label_timer += delta
			var t: float = clamp(_night_label_timer / _NIGHT_LABEL_FADE_IN_DURATION, 0.0, 1.0)
			_night_label.modulate = Color(1.0, 1.0, 1.0, t)
			if _night_label_timer >= _NIGHT_LABEL_FADE_IN_DURATION:
				_night_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
				_night_label_timer = 0.0
				_state = State.HOLDING_NIGHT_LABEL
		State.HOLDING_NIGHT_LABEL:
			if _sfx_finished:
				_night_label_timer = 0.0
				_state = State.FADING_OUT_NIGHT_LABEL
		State.FADING_OUT_NIGHT_LABEL:
			_night_label_timer += delta
			var t: float = clamp(_night_label_timer / _NIGHT_LABEL_FADE_OUT_DURATION, 0.0, 1.0)
			_night_label.modulate = Color(1.0, 1.0, 1.0, 1.0 - t)
			if _night_label_timer >= _NIGHT_LABEL_FADE_OUT_DURATION:
				_night_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
				_buzzer_interval = 0.0
				_buzzer_timer = 0.0
				_show_elevator()
				_state = State.SHOWING_ELEVATOR
		State.SHOWING_ELEVATOR:
			_play_audio("RedButtonHint.ogg", CAPTION_RED_BUTTON)
			_state = State.PLAYING_RED_BUTTON_HINT
		State.PLAYING_RED_BUTTON_HINT:
			pass
		State.WAITING_RED_BUTTON:
			_recompute_red_button_rect()
		State.PLAYING_DOOR_ANIM:
			pass
		State.DONE:
			pass

func _load_door_frames() -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var folder_path: String = "res://animations/Doors/"
	var start := 1
	for probe in range(1, 10000):
		if ResourceLoader.exists(folder_path + ("frame_%04d.png" % probe)):
			start = probe
			break
	var i := start
	while true:
		var path: String = folder_path + ("frame_%04d.png" % i)
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				frames.append(tex)
			i += 1
		else:
			break
	if frames.is_empty():
		push_error("HandUnitAnimator: No frames found in: %s" % folder_path)
	if debug_prints:
		print("[HandUnitAnimator] Loaded %d door frames from %s" % [frames.size(), folder_path])
	return frames

func _extract_frame_number(filename: String) -> int:
	var parts := filename.get_basename().split("_")
	if parts.size() >= 2 and parts[-1].is_valid_int():
		return parts[-1].to_int()
	return 0

func _show_elevator() -> void:
	if dark_elevator_texture == null:
		push_error("HandUnitAnimator: dark_elevator_texture is not set in the Inspector.")
		_state = State.DONE
		return
	var bg := get_tree().get_first_node_in_group("background_animator")
	if bg == null:
		push_error("HandUnitAnimator: No node in group 'background_animator' found.")
		_state = State.DONE
		return
	bg.freeze_on_elevator(dark_elevator_texture)
	_recompute_red_button_rect()
	if debug_prints:
		print("[HandUnitAnimator] Showing dark elevator via background_animator.")
