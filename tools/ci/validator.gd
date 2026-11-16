# Loads every script, scene and resource in the project and fails on any that
# don't load. Runs as a scene (not --script) so autoloads exist, matching runtime.
extends Node

const SKIP_DIRS: PackedStringArray = [".godot", ".git", ".toolchain", "addons", "build"]
const SELF_SCENE: String = "res://tools/ci/validator.tscn"

var _checked: int = 0
var _failures: PackedStringArray = []


func _ready() -> void:
	var files: PackedStringArray = []
	_collect("res://", files)
	for path: String in files:
		_check(path)
	print("VALIDATOR checked=%d failed=%d" % [_checked, _failures.size()])
	for f: String in _failures:
		printerr("VALIDATOR FAIL ", f)
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		_failures.append("cannot open dir " + dir_path)
		return
	for sub: String in dir.get_directories():
		if sub in SKIP_DIRS:
			continue
		_collect(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		var ext: String = file.get_extension()
		if ext == "gd" or ext == "tscn" or ext == "tres":
			out.append(dir_path.path_join(file))


func _check(path: String) -> void:
	if path == SELF_SCENE:
		return
	_checked += 1
	var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		_failures.append("load failed: " + path)
		return
	if res is PackedScene:
		var inst: Node = (res as PackedScene).instantiate()
		if inst == null:
			_failures.append("instantiate failed: " + path)
			return
		inst.free()
