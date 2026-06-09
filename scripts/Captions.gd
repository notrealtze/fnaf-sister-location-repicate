extends Node

@export var chars_per_second: float = 42.0
@export var popup_duration: float = 0.3
@export var fadeout_duration: float = 0.8
@export var caption_width: float = 900.0
@export var font_size: int = 26
@export var caption_font: FontFile = null

const CAPTION_SKIP_HINT := "[center][color=#888888][i]PRESS SPACE TO SKIP[/i][/color][/center]"

enum CaptionState { IDLE, TYPING, HOLDING, FADING_OUT }

var _caption_state: CaptionState = CaptionState.IDLE
var _char_index: float = 0.0
var _hold_timer: float = 0.0
var _fade_timer: float = 0.0
var _popup_timer: float = 0.0
var _is_popping_up: bool = false
var _current_alpha: float = 0.0
var _tracked_player: AudioStreamPlayer = null
var _auto_hide: bool = true

var _shake_timer: float = 0.0
var _shake_active: bool = false

var _label: RichTextLabel = null
var _skip_label: RichTextLabel = null

func _ready() -> void:
	call_deferred("_build_ui")

func _build_ui() -> void:
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible_characters = 0
	_label.custom_minimum_size = Vector2(caption_width, 0.0)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.z_index = 400
	_apply_font(_label, font_size)
	_label.add_theme_color_override("default_color", Color(1.0, 1.0, 1.0, 1.0))
	_label.add_theme_constant_override("line_separation", 6)
	_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_label.text = ""
	get_tree().current_scene.add_child(_label)

	_skip_label = RichTextLabel.new()
	_skip_label.bbcode_enabled = true
	_skip_label.fit_content = true
	_skip_label.scroll_active = false
	_skip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_label.custom_minimum_size = Vector2(caption_width, 0.0)
	_skip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skip_label.z_index = 400
	_apply_font(_skip_label, 16)
	_skip_label.add_theme_color_override("default_color", Color(1.0, 1.0, 1.0, 1.0))
	_skip_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_skip_label.text = CAPTION_SKIP_HINT
	get_tree().current_scene.add_child(_skip_label)

	_reposition()
	get_viewport().size_changed.connect(_reposition)

func _apply_font(lbl: RichTextLabel, size: int) -> void:
	if caption_font != null:
		lbl.add_theme_font_override("normal_font", caption_font)
		lbl.add_theme_font_override("bold_font", caption_font)
	else:
		var font_path := "res://fonts/ArsenalSC-Regular.ttf"
		if ResourceLoader.exists(font_path):
			var fnt := load(font_path) as FontFile
			if fnt:
				lbl.add_theme_font_override("normal_font", fnt)
				lbl.add_theme_font_override("bold_font", fnt)
	lbl.add_theme_font_size_override("normal_font_size", size)
	lbl.add_theme_font_size_override("bold_font_size", size)

func _reposition() -> void:
	if _label == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var label_h: float = _label.get_minimum_size().y
	_label.position = Vector2(
		(screen.x - caption_width) / 2.0,
		screen.y - label_h - 10.0
	)
	if _skip_label != null:
		var skip_h: float = _skip_label.get_minimum_size().y
		_skip_label.position = Vector2(
			(screen.x - caption_width) / 2.0,
			screen.y - label_h - skip_h - 16.0
		)

func show_caption(bbcode: String, audio_player: AudioStreamPlayer = null, auto_hide: bool = true) -> void:
	if _label == null:
		return
	_tracked_player = audio_player
	_auto_hide = auto_hide
	_label.text = bbcode
	_label.visible_characters = 0
	_char_index = 0.0
	_hold_timer = 0.0
	_fade_timer = 0.0
	_caption_state = CaptionState.TYPING
	_popup_timer = 0.0
	_is_popping_up = true
	_current_alpha = 0.0
	_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_label.scale = Vector2(0.88, 0.88)
	_label.pivot_offset = Vector2(caption_width / 2.0, 0.0)
	_skip_label.modulate = Color(1.0, 1.0, 1.0, 0.0)

func hide_caption() -> void:
	if _label == null:
		return
	_caption_state = CaptionState.IDLE
	_current_alpha = 0.0
	_tracked_player = null
	_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_label.visible_characters = 0
	_label.text = ""
	_skip_label.modulate = Color(1.0, 1.0, 1.0, 0.0)

func force_fade() -> void:
	if _caption_state == CaptionState.IDLE or _caption_state == CaptionState.FADING_OUT:
		return
	_caption_state = CaptionState.FADING_OUT
	_fade_timer = 0.0
	_skip_label.modulate = Color(1.0, 1.0, 1.0, 0.0)

func _audio_still_playing() -> bool:
	return _tracked_player != null and _tracked_player.playing

func _input(event: InputEvent) -> void:
	if _caption_state != CaptionState.HOLDING:
		return
	if _audio_still_playing():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		force_fade()

func _process(delta: float) -> void:
	if _label == null:
		return
	_process_popup(delta)
	_process_caption(delta)
	if not _shake_active:
		_reposition()
	_process_shake(delta)

func _process_popup(delta: float) -> void:
	if not _is_popping_up:
		return
	_popup_timer += delta
	var t: float = clamp(_popup_timer / popup_duration, 0.0, 1.0)
	var ease_t: float = 1.0 - pow(1.0 - t, 3.0)
	_current_alpha = ease_t
	_label.modulate = Color(1.0, 1.0, 1.0, _current_alpha)
	_label.scale = Vector2(lerp(0.88, 1.0, ease_t), lerp(0.88, 1.0, ease_t))
	if _popup_timer >= popup_duration:
		_is_popping_up = false
		_current_alpha = 1.0
		_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_label.scale = Vector2(1.0, 1.0)

func _process_caption(delta: float) -> void:
	match _caption_state:
		CaptionState.TYPING:
			_char_index += chars_per_second * delta
			_label.visible_characters = int(_char_index)
			if _label.visible_characters >= _label.get_total_character_count():
				_label.visible_characters = -1
				_caption_state = CaptionState.HOLDING
				_hold_timer = 0.0
		CaptionState.HOLDING:
			_hold_timer += delta
			var audio_done: bool = not _audio_still_playing()
			if audio_done:
				_skip_label.modulate = Color(1.0, 1.0, 1.0, 0.6)
				if _hold_timer >= 0.3:
					force_fade()
			else:
				_skip_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
		CaptionState.FADING_OUT:
			_fade_timer += delta
			var t: float = clamp(_fade_timer / fadeout_duration, 0.0, 1.0)
			_current_alpha = 1.0 - t
			_label.modulate = Color(1.0, 1.0, 1.0, _current_alpha)
			if _fade_timer >= fadeout_duration:
				hide_caption()

func start_shake() -> void:
	_shake_active = true
	_shake_timer = 0.0

func _process_shake(delta: float) -> void:
	if not _shake_active:
		return
	_shake_timer += delta
	var shake_duration: float = 0.35
	if _shake_timer >= shake_duration:
		_shake_active = false
		_reposition()
		return
	var intensity: float = lerp(6.0, 0.0, _shake_timer / shake_duration)
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var label_h: float = _label.get_minimum_size().y
	_label.position = Vector2(
		(screen.x - caption_width) / 2.0 + randf_range(-intensity, intensity),
		screen.y - label_h - 10.0 + randf_range(-intensity, intensity)
	)
