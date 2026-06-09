extends RichTextLabel

var current_fps: float = 0.0
var smooth_speed: float = 5.0

func _ready() -> void:
	fit_content = true

func _process(delta: float) -> void:
	current_fps = lerp(current_fps, float(Engine.get_frames_per_second()), delta * smooth_speed)
	var fps := int(current_fps)
	var color: String
	if fps >= 60:
		color = "green"
	elif fps >= 30:
		color = "yellow"
	else:
		color = "red"
	text = "[color=%s]FPS: %d[/color]" % [color, fps]