# FrameGovernor: with Settings "slow_down_on_lag" on, the game slows down instead of piling up
# physics steps when frames get long. Godot runs as many physics steps (physics_fps) a frame as the frame took
# (up to 8): a slow frame brings more steps, which make the next frame slower still (a crowded fight
# on a phone fell to 5-10 FPS). The governor watches the real frame time (averaged, LAG_AVERAGE_FRAMES)
# and sets the game speed so a frame runs at most LAG_MAX_STEPS steps, never below LAG_MIN_SPEED:
# Engine.time_scale and Engine.iterations_per_second go down together, so each step is still one physics step
# of game time (flight, weapons and AI work exactly as at full speed), only fewer run each second.
# Speed falls at once and comes back gradually (LAG_RECOVERY per frame). Off, it leaves the engine
# at full speed (and touches nothing unless it had slowed it). The HUD frame readout shows the speed.
# The evolution sim runs on Settings' defaults (off) and sets the engine itself.

extends Node
const Interp = preload("res://src/core/utils/interp.gd")


var speed: float = 1.0  # Game speed now (1: full)
var _enabled: bool = false
var _average: float = 1.0 / 60.0  # s per frame, real time
var _last_usec: int = 0


func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS
	_enabled = bool(Settings.get_option("slow_down_on_lag"))
	Settings.connect("changed", self, "_on_settings_changed")


func _exit_tree() -> void:
	_set_speed(1.0)


func _on_settings_changed(key, value) -> void:
	if key == "slow_down_on_lag":
		_enabled = bool(value)
		if not _enabled:
			_set_speed(1.0)


func _process(_delta: float) -> void:
	var now: int = OS.get_ticks_usec()
	var frame: float = (now - _last_usec) / 1000000.0
	_last_usec = now
	if not _enabled or get_tree().paused or frame <= 0.0 or frame > 1.0:
		return  # Off, paused (a menu) or a hitch such as a load: nothing to go by
	_average = lerp(_average, frame, 1.0 / Constants.LAG_AVERAGE_FRAMES)
	var wanted: float = wanted_speed(_average)
	_set_speed(wanted if wanted < speed else lerp(speed, wanted, Constants.LAG_RECOVERY))


# The game speed at which a frame of `frame_seconds` runs at most LAG_MAX_STEPS steps.
static func wanted_speed(frame_seconds: float) -> float:
	return clamp(Constants.LAG_MAX_STEPS / (Interp.physics_rate() * max(frame_seconds, 0.0001)), Constants.LAG_MIN_SPEED, 1.0)


# Whole steps per second (iterations_per_second is an int): speed is set to match them exactly, so a
# step stays one physics step of game time.
func _set_speed(value: float) -> void:
	var rate: int = int(clamp(round(Interp.physics_rate() * value), 1, Interp.physics_rate()))
	var new_speed: float = float(rate) / Interp.physics_rate()
	if is_equal_approx(new_speed, speed) and Engine.iterations_per_second == rate:
		return
	if new_speed >= 1.0 and is_equal_approx(speed, 1.0):
		return  # Never slowed: leave the engine as whoever set it left it
	speed = new_speed
	Engine.iterations_per_second = rate
	Engine.time_scale = new_speed
