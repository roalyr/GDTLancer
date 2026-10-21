# FrameProfiler: where frame time goes, cheaply enough to leave on while tuning (shown in the HUD
# readout). It splits each frame into its physics steps (scripts and Bullet) and the rest (idle
# processing, rendering and the buffer swap), from the SceneTree's physics_frame and idle_frame
# signals, and sums named sections the code marks with begin()/end(). Figures are averages per
# frame over the last REPORT_INTERVAL seconds.
# The HUD adds one as a child; sections reach it through the tree's meta, so code that marks a
# section needs no reference to it and costs two ticks reads when none is running.

extends Node

const REPORT_INTERVAL = 1.0  # s
const META = "frame_profiler"

var report: Dictionary = {}  # Last interval: frame_ms, physics_ms, steps, idle_ms, sections {name: ms}

var _frames := 0
var _steps := 0
var _physics_us := 0
var _idle_us := 0
var _sections := {}  # name -> usec this interval
var _open := {}  # name -> usec at begin()
var _phys_start := 0
var _idle_start := 0
var _in_physics := false
var _interval_start := 0


func _enter_tree() -> void:
	get_tree().set_meta(META, self)
	get_tree().connect("physics_frame", self, "_on_physics_frame")
	get_tree().connect("idle_frame", self, "_on_idle_frame")
	_interval_start = OS.get_ticks_usec()


func _exit_tree() -> void:
	if get_tree().has_meta(META) and get_tree().get_meta(META) == self:
		get_tree().remove_meta(META)
	get_tree().disconnect("physics_frame", self, "_on_physics_frame")
	get_tree().disconnect("idle_frame", self, "_on_idle_frame")


# Marks the start of a named section (pair with end()); a no-op unless a profiler runs.
static func begin(tree: SceneTree, section: String) -> void:
	if tree.has_meta(META):
		tree.get_meta(META)._open[section] = OS.get_ticks_usec()


static func end(tree: SceneTree, section: String) -> void:
	if tree.has_meta(META):
		var profiler = tree.get_meta(META)
		if profiler._open.has(section):
			profiler._sections[section] = profiler._sections.get(section, 0) + OS.get_ticks_usec() - profiler._open[section]


# Physics steps run back to back before a frame's idle part: time from the first to the idle.
func _on_physics_frame() -> void:
	var now: int = OS.get_ticks_usec()
	_steps += 1
	if not _in_physics:
		if _idle_start > 0:
			_idle_us += now - _idle_start
			_idle_start = 0
		_phys_start = now
		_in_physics = true


func _on_idle_frame() -> void:
	var now: int = OS.get_ticks_usec()
	if _in_physics:
		_physics_us += now - _phys_start
		_in_physics = false
	elif _idle_start > 0:
		_idle_us += now - _idle_start
	_idle_start = now
	_frames += 1
	if now - _interval_start >= REPORT_INTERVAL * 1000000.0:
		_publish(now)


func _publish(now: int) -> void:
	var frames: float = max(_frames, 1)
	var sections := {}
	for name in _sections:
		sections[name] = _sections[name] / frames / 1000.0
	report = {
		"frame_ms": (now - _interval_start) / frames / 1000.0,
		"physics_ms": _physics_us / frames / 1000.0,
		"steps": _steps / frames,
		"idle_ms": _idle_us / frames / 1000.0,
		"sections": sections,
	}
	_frames = 0
	_steps = 0
	_physics_us = 0
	_idle_us = 0
	_sections = {}
	_interval_start = now
