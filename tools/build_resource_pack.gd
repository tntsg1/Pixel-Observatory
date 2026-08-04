extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Usage: --script build_resource_pack.gd -- <output.pck> <resource>...")
		quit(2)
		return

	var packer := PCKPacker.new()
	var output_path := ProjectSettings.globalize_path(args[0])
	var start_error := packer.pck_start(output_path)
	if start_error != OK:
		push_error("Could not create resource pack %s: %s" % [output_path, error_string(start_error)])
		quit(start_error)
		return

	var packed: Dictionary = {}
	for index in range(1, args.size()):
		var resource_path := String(args[index])
		if not resource_path.begins_with("res://"):
			resource_path = "res://" + resource_path.trim_prefix("/")
		var import_path := resource_path + ".import"
		if FileAccess.file_exists(import_path):
			_add_file(packer, import_path, packed)
			var import_config := ConfigFile.new()
			if import_config.load(import_path) != OK:
				push_error("Could not read import metadata for %s" % resource_path)
				quit(3)
				return
			for key in import_config.get_section_keys("remap"):
				if String(key).begins_with("path"):
					var imported_path := String(import_config.get_value("remap", key, ""))
					if imported_path.begins_with("res://"):
						_add_file(packer, imported_path, packed)
		else:
			_add_file(packer, resource_path, packed)

	var flush_error := packer.flush()
	if flush_error != OK:
		push_error("Could not finish resource pack %s: %s" % [output_path, error_string(flush_error)])
		quit(flush_error)
		return
	print("Packed %d imported files into %s" % [packed.size(), output_path])
	quit()

func _add_file(packer: PCKPacker, resource_path: String, packed: Dictionary) -> void:
	if packed.has(resource_path):
		return
	var source_path := ProjectSettings.globalize_path(resource_path)
	if not FileAccess.file_exists(source_path):
		push_error("Resource-pack input is missing: %s" % resource_path)
		quit(4)
		return
	var add_error := packer.add_file(resource_path, source_path)
	if add_error != OK:
		push_error("Could not add %s: %s" % [resource_path, error_string(add_error)])
		quit(add_error)
		return
	packed[resource_path] = true
