extends AudioStreamPlayer2D

@export var fade_out_duration: float = 1.0

var _fading: bool = false
var _fade_timer: float = 0.0
var _start_volume: float = 0.0

func mute_immediate() -> void:
	stop()
	volume_db = -80.0

func fade_out_and_mute() -> void:
	if not playing:
		return
	_start_volume = volume_db
	_fade_timer = 0.0
	_fading = true

func restore() -> void:
	_fading = false
	volume_db = _start_volume
	play()

func _process(delta: float) -> void:
	if not _fading:
		return
	_fade_timer += delta
	var t: float = clamp(_fade_timer / fade_out_duration, 0.0, 1.0)
	volume_db = lerpf(_start_volume, -80.0, t)
	if t >= 1.0:
		_fading = false
		stop()
		volume_db = -80.0
