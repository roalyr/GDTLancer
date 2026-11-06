# Validate: prints every content problem (ContentValidator: the rules the content tests and the
# development tool use) and exits 1 if there are any. tools/dev.py validate runs it.
#     godot --no-window -s tools/devtool/validate.gd [-- section]
extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var validator = load("res://src/core/validation/content_validator.gd")  # After the autoloads (its rules use Constants)
	var args: Array = OS.get_cmdline_args()
	var sections: Array = validator.SECTIONS
	if args.has("--") and args.find("--") + 1 < args.size():
		sections = [args[args.find("--") + 1]]
	var count := 0
	for section in sections:
		var problems: Array = validator.section(section)
		print("%-11s %s" % [section, "OK" if problems.empty() else "%d problem(s)" % problems.size()])
		for problem in problems:
			print("    %s: %s" % [problem.file, problem.problem])
		count += problems.size()
	quit(1 if count > 0 else 0)
