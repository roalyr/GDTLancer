# PROJECT: GDTLancer
# MODULE: game_start_template.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-08-18 07:53:00

extends Template
class_name GameStartTemplate

export var player_character_template: String = "character_default"
export var player_ship_template: String = "ship_default"
export var player_starting_location: String = ""
