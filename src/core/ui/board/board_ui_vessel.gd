# PROJECT: GDTLancer
# MODULE: board_ui_vessel.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# LOG_REF: 2026-07-26 07:55:00

extends "res://src/core/ui/board/board_ui.gd"

func _ready() -> void:
	._ready()

func _populate_board() -> void:
	._populate_board()
	
	if board_title_label != null:
		board_title_label.text = "VESSEL & CREW TABLETOP INTERFACE"
		
	# Populate Ship System & Crew Tokens
	if token_grid != null:
		for child in token_grid.get_children():
			child.queue_free()
			
		var vessel_tokens: Array = [
			{"id": "vessel_reactor", "name": "Engine Reactor", "label": "[SYSTEM] Engine Reactor\nStatus: STABLE", "locked": false},
			{"id": "vessel_life_support", "name": "Life Support Array", "label": "[SYSTEM] Life Support\nStatus: NOMINAL", "locked": false},
			{"id": "vessel_cargo", "name": "Cargo Bay Hold", "label": "[SYSTEM] Cargo Hold\nStatus: 80% Capacity", "locked": false},
			{"id": "crew_engineer", "name": "Chief Engineer", "label": "[CREW] Chief Engineer\nRole: Maintenance", "locked": false},
			{"id": "crew_pilot", "name": "Flight Specialist", "label": "[CREW] Flight Specialist\nRole: Navigation", "locked": false}
		]
		
		for data in vessel_tokens:
			var btn = Button.new()
			btn.rect_min_size = Vector2(130, 80)
			btn.text = data["label"]
			if data["id"].begins_with("crew_"):
				btn.add_color_override("font_color", Color(0.4, 1.0, 0.8, 1.0))
			else:
				btn.add_color_override("font_color", Color(1.0, 0.8, 0.4, 1.0))
			btn.connect("pressed", self, "_on_target_token_pressed", [data])
			token_grid.add_child(btn)
