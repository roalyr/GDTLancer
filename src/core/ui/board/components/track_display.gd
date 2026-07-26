# PROJECT: GDTLancer
# MODULE: track_display.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-07-26 01:57:00

extends Control
class_name TrackDisplay

var track_name: String = "health"
var track_type: String = "player" # "player" or "sector"
var sector_id: String = ""

var title_label: Label = null
var value_label: Label = null
var tier_label: Label = null
var progress_bar: ProgressBar = null

func _ready() -> void:
	title_label = get_node_or_null("VBoxContainer/TitleLabel") as Label
	value_label = get_node_or_null("VBoxContainer/ValueLabel") as Label
	tier_label = get_node_or_null("VBoxContainer/TierLabel") as Label
	progress_bar = get_node_or_null("VBoxContainer/ProgressBar") as ProgressBar
	
	if EventBus != null and EventBus.has_signal("player_track_changed"):
		EventBus.connect("player_track_changed", self, "_on_player_track_changed")
	
	update_display()

func setup_track(p_name: String, p_type: String = "player", p_sector_id: String = "") -> void:
	track_name = p_name
	track_type = p_type
	sector_id = p_sector_id
	update_display()

func update_display() -> void:
	var val: int = 0
	var tier: String = "STABLE"
	
	if track_type == "player":
		val = GameState.get_player_track(track_name)
		tier = GameState.get_player_track_tier(track_name)
		if title_label != null:
			title_label.text = track_name.capitalize()
			title_label.add_color_override("font_color", Color(0.4, 0.8, 1.0, 1.0))
	else:
		val = GameState.get_sector_track(sector_id, track_name)
		if GameState.has_method("get_sector_track_tier"):
			tier = GameState.get_sector_track_tier(sector_id, track_name)
		else:
			if val <= 2: tier = "CRITICAL"
			elif val <= 4: tier = "LOW"
			elif val <= 7: tier = "STABLE"
			else: tier = "PROSPEROUS"
		if title_label != null:
			title_label.text = "Sector " + track_name.capitalize()
			title_label.add_color_override("font_color", Color(0.95, 0.75, 0.25, 1.0))
		
	if value_label != null:
		value_label.text = str(val) + " / 10"
	if tier_label != null:
		tier_label.text = "[" + tier + "]"
	if progress_bar != null:
		progress_bar.value = val

func _on_player_track_changed(t_name: String, new_val: int) -> void:
	if track_type == "player" and t_name == track_name:
		update_display()
