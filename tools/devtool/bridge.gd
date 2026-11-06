# Bridge: the development tool's line to Godot (tools/devtool/bridge.py starts it). Reads one JSON
# request per line on stdin, {"id": n, "cmd": name, "args": {...}}, runs it (BridgeCommands) and
# answers on stdout with one line, the marker REPLY followed by {"id": n, "ok": ..., "result" or
# "error"}. Everything else Godot prints is not a reply. An empty line or {"cmd": "quit"} ends it.
#     godot --no-window -s tools/devtool/bridge.gd

extends SceneTree

const REPLY = "@@BRIDGE "
const COMMANDS = "res://tools/devtool/bridge_commands.gd"  # Loaded once the autoloads are up (its rules use Constants)

var _commands = null


func _initialize() -> void:
	call_deferred("_serve")


func _serve() -> void:
	_commands = load(COMMANDS).new()
	print(REPLY + to_json({"id": 0, "ok": true, "result": "ready"}))
	while true:
		var line: String = OS.read_string_from_stdin().strip_edges()
		if line == "":
			break
		var parsed: JSONParseResult = JSON.parse(line)
		if parsed.error != OK or not parsed.result is Dictionary:
			print(REPLY + to_json({"id": -1, "ok": false, "error": "Not a JSON object: " + line.substr(0, 200)}))
			continue
		var request: Dictionary = parsed.result
		if request.get("cmd", "") == "quit":
			break
		var reply: Dictionary = _commands.handle(str(request.get("cmd", "")), request.get("args", {}) if request.get("args") is Dictionary else {})
		reply["id"] = request.get("id", -1)
		print(REPLY + _commands.json(reply))
	quit()
