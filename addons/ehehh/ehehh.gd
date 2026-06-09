@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_tool_menu_item("Apply Frame Quality Settings", _on_button_pressed)

func _exit_tree() -> void:
	remove_tool_menu_item("Apply Frame Quality Settings")

func _on_button_pressed() -> void:
	_apply_project_settings()
	_reimport_frames()

func _apply_project_settings() -> void:
	ProjectSettings.set_setting("rendering/textures/default_filters/default_texture_filter", 3)
	ProjectSettings.set_setting("display/window/stretch/mode", "canvas_items")
	ProjectSettings.set_setting("display/window/stretch/aspect", "expand")
	ProjectSettings.save()
	print("Project settings applied.")

func _reimport_frames() -> void:
	var files := _collect_frames("res://animations/")
	if files.is_empty():
		push_error("No frame_XXXX.png files found.")
		return
	for path in files:
		_set_import_settings(path)
	EditorInterface.get_resource_filesystem().reimport_files(files)
	print("Reimported %d frames with improved quality." % files.size())

func _collect_frames(folder: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.match("frame_*.png"):
			result.append(folder.path_join(file))
		file = dir.get_next()
	dir.list_dir_end()
	return result

func _set_import_settings(path: String) -> void:
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		return
	var file := FileAccess.open(import_path, FileAccess.READ)
	var content := file.get_as_text()
	file.close()
	content = _replace_or_append(content, "filter", "true")
	content = _replace_or_append(content, "mipmaps/generate", "true")
	var out := FileAccess.open(import_path, FileAccess.WRITE)
	out.store_string(content)
	out.close()

func _replace_or_append(content: String, key: String, value: String) -> String:
	var regex := RegEx.new()
	regex.compile(key + "=.*")
	if regex.search(content):
		return regex.sub(content, key + "=" + value)
	return content + "\n" + key + "=" + value