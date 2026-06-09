@tool
extends EditorPlugin

var exporter_instance: CodeOnlyExporter

class CodeOnlyExporter extends EditorExportPlugin:
	func _get_name() -> String:
		return "CodeOnlyExporter"

	func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
		run_asset_packing_logic()

	func run_asset_packing_logic() -> void:
		var target_folder := "res://assets/dynamic_images/"
		_scan_and_include_dir(target_folder)

	func _scan_and_include_dir(path: String) -> void:
		if not DirAccess.dir_exists_absolute(path):
			return
			
		var dir := DirAccess.open(path)
		if dir:
			dir.list_dir_begin()
			var file_name := dir.get_next()
			while file_name != "":
				if dir.current_is_dir():
					if file_name != "." and file_name != "..":
						_scan_and_include_dir(path + file_name + "/")
				else:
					if file_name.ends_with(".png"):
						var full_file_path := path + file_name
						var file_bytes := FileAccess.get_file_as_bytes(full_file_path)
						if file_bytes.size() > 0:
							add_file(full_file_path, file_bytes, false)
			file_name = dir.get_next()

func _enter_tree() -> void:
	exporter_instance = CodeOnlyExporter.new()
	add_export_plugin(exporter_instance)
	add_tool_menu_item("Pack Dynamic Assets Now", _on_tools_menu_pressed)

func _exit_tree() -> void:
	remove_tool_menu_item("Pack Dynamic Assets Now")
	remove_export_plugin(exporter_instance)
	exporter_instance = null

func _on_tools_menu_pressed() -> void:
	if exporter_instance:
		exporter_instance.run_asset_packing_logic()
		print("CodeOnlyExporter: Handled asset sweep via Project Tools execution successfully.")
