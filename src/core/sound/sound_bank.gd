# SoundBank: the game's sound effects, one slot per event (CONTENT.md, "Sounds"). The game's bank is
# database/sounds/sound_bank.tres; SoundEffects (in the main scene) plays it. A slot left empty
# is silent, so slots can be filled one at a time.
# Slot kinds (SLOTS):
#   "world": heard where it happens, fading with distance from the player's ship;
#   "loop":  a looping sound carried by every ship (or missile) while it flies; its stream must be
#            imported with looping on (Godot's Import dock: "Loop");
#   "ui":    heard as it is, wherever the player is (buttons, notices, docking).

extends Resource

const SLOTS = {
	# Weapons and tools, at the ship using them
	"laser_hit": "world",  # Where a laser beam lands (a ship, a rock, a missile it shoots down): a welding spark
	"cannon_fire": "world",
	"cannon_hit": "world",  # A cannon round meets a ship, at the hit
	"missile_launch": "world",  # The hardpoint lets the missile go: a click
	"missile_burst": "world",  # A missile goes off: on a hit, or shot down
	"rock_hit": "world",  # A round or missile meets a rock
	"harpoon_launch": "world",  # The hook fired: a pneumatic thump
	"harpoon_hook": "world",  # The hook clamps on, at the towed body: a metal clank and latch
	"salvage": "world",  # A harpoon strips salvage, rounds or a lance off a wreck
	"lance_launch": "world",  # A massive mechanical throw
	"lance_strike": "world",  # A dull thud, at the target
	"lance_glance": "world",  # Too slow or at an angle: at the target
	# Ships
	"hull_hit": "world",  # Damage no weapon's own hit sound covers (radiation, a collision), at the ship
	"ship_wrecked": "world",  # Hull at zero: the ship blows up
	"engine": "loop",  # Every ship's engine; louder with speed, pitched up while the afterburner burns
	"laser_hum": "loop",  # A ship with a laser on: the low hum of high-current circuits, quiet
	"harpoon_reel": "loop",  # A ship's harpoon winch turning: reeling in, or pulling a loose cable back
	"missile_engine": "loop",  # A missile's thruster
	# The player's screen
	"ui_press": "ui",  # Any button
	"notice_info": "ui",  # HUD announcements, by level
	"notice_warning": "ui",
	"notice_danger": "ui",
	"radio": "ui",  # An NPC on the common frequency
	"hostile_detected": "ui",  # A hostile comes onto the sensors (ThreatWatch)
	"hostile_aware": "ui",  # A hostile the player sees has detected it
	"dock_ready": "ui",  # In docking range
	"docked": "ui",
	"undocked": "ui",
}

export(AudioStream) var laser_hit
export(AudioStream) var cannon_fire
export(AudioStream) var cannon_hit
export(AudioStream) var missile_launch
export(AudioStream) var missile_burst
export(AudioStream) var rock_hit
export(AudioStream) var harpoon_launch
export(AudioStream) var harpoon_hook
export(AudioStream) var salvage
export(AudioStream) var lance_launch
export(AudioStream) var lance_strike
export(AudioStream) var lance_glance
export(AudioStream) var hull_hit
export(AudioStream) var ship_wrecked
export(AudioStream) var engine
export(AudioStream) var laser_hum
export(AudioStream) var harpoon_reel
export(AudioStream) var missile_engine
export(AudioStream) var ui_press
export(AudioStream) var notice_info
export(AudioStream) var notice_warning
export(AudioStream) var notice_danger
export(AudioStream) var radio
export(AudioStream) var hostile_detected
export(AudioStream) var hostile_aware
export(AudioStream) var dock_ready
export(AudioStream) var docked
export(AudioStream) var undocked


# The stream in `slot`, or null when it is empty. An unknown slot is an error.
func stream(slot: String) -> AudioStream:
	if not SLOTS.has(slot):
		push_error("SoundBank: no slot '%s'" % slot)
		return null
	return get(slot)
