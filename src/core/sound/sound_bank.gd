# SoundBank: the game's sound effects, one slot per event (CONTENT.md, "Sounds"). The game's bank is
# database/sounds/sound_bank.tres; SoundEffects (in the main scene) plays it. A slot left empty
# is silent, so slots can be filled one at a time.
# Slot kinds (SLOTS):
#   "world": heard where it happens, fading with distance from the player's ship;
#   "loop":  a looping sound carried by a ship (or missile) while it applies; its stream must be
#            imported with looping on (Godot's Import dock: "Loop"). Only the nearest
#            SOUND_LOOP_CARRIERS ships and missiles play theirs;
#   "ui":    heard as it is, wherever the player is (buttons, notices, docking, the player's alarms);
#   "ambient": heard as it is, a loop that plays while a state lasts (a jump's travel), fading in and
#            out (SOUND_AMBIENT_FADE); its stream must be imported with looping on, as a "loop" slot's.
# Every slot plays on the "Effects" bus (AudioBuses).

extends Resource

const LOOPING_KINDS = ["loop", "ambient"]  # Slot kinds whose sounds must loop

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
	"rock_break": "world",  # A lance breaks chunks off a rock: grinding stone, at the chunks
	"tool_on": "world",  # A ship switches a tool on (a relay clack)
	"tool_off": "world",  # ... and off again (not when it only changes target)
	"out_of_ammo": "world",  # A gun or rack goes off for want of rounds: a dry click
	"cable_retracted": "world",  # A harpoon cable is wound all the way home: a latch
	"decoy_launch": "world",  # A decoy flare thrown at a missile: a pop and hiss
	"afterburner_ignite": "world",  # The afterburner lights: a roar on top of the engine's pitch
	# Ships
	"hull_hit": "world",  # Damage no weapon's own hit sound covers (radiation, a collision), at the ship
	"ship_wrecked": "world",  # Hull at zero: the ship blows up
	"engine": "loop",  # Every ship's engine; louder with speed, pitched up while the afterburner burns
	"laser_hum": "loop",  # A ship with a laser on: the low hum of high-current circuits, quiet
	"harpoon_reel": "loop",  # A ship's harpoon winch turning: reeling in, or pulling a loose cable back
	"missile_engine": "loop",  # A missile's thruster
	"fuel_leak": "loop",  # A ship venting fuel from its leaks: a hiss
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
	"lance_warning": "ui",  # A lance is charging the player's ship (agent_charged)
	"hull_critical": "ui",  # The player's hull falls to SOUND_HULL_CRITICAL_SHARE
	"power_empty": "ui",  # The player's power runs out
	"hold_full": "ui",  # The player's harpoon has a wreck in but the hold has no room
	"target_selected": "ui",  # The player picks a target
	"trade": "ui",  # The player buys or sells (parts, ships, cargo)
	"interaction": "ui",  # The player's interactions (hire, wing, caravan) start or end
	# Ambience
	"jump_travel": "ambient",  # The jump between sectors, from the run-up to the arrival (the hum of the jump drive, the rush of the passage)
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
export(AudioStream) var rock_break
export(AudioStream) var tool_on
export(AudioStream) var tool_off
export(AudioStream) var out_of_ammo
export(AudioStream) var cable_retracted
export(AudioStream) var decoy_launch
export(AudioStream) var afterburner_ignite
export(AudioStream) var fuel_leak
export(AudioStream) var lance_warning
export(AudioStream) var hull_critical
export(AudioStream) var power_empty
export(AudioStream) var hold_full
export(AudioStream) var target_selected
export(AudioStream) var trade
export(AudioStream) var interaction
export(AudioStream) var jump_travel


# Whether `slot`'s sound must loop (its kind is one of LOOPING_KINDS).
static func loops(slot: String) -> bool:
	return SLOTS.get(slot, "") in LOOPING_KINDS


# The stream in `slot`, or null when it is empty. An unknown slot is an error.
func stream(slot: String) -> AudioStream:
	if not SLOTS.has(slot):
		push_error("SoundBank: no slot '%s'" % slot)
		return null
	return get(slot)
