# PROJECT: GDTLancer
# MODULE: board_ui_survey.gd
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
		board_title_label.text = "STELLAR SURVEY & PROSPECTING BOARD"
		
	# Populate Prospecting & Survey Tokens
	if token_grid != null:
		for child in token_grid.get_children():
			child.queue_free()
			
		var survey_tokens: Array = [
			{"id": "survey_mineral", "name": "Mineral Core Site", "label": "[PROSPECT] Mineral Core\nReq: Sensor Sweep", "locked": false},
			{"id": "survey_atmosphere", "name": "Atmospheric Density", "label": "[SURVEY] Atmosphere Probe\nReq: Sensor Sweep", "locked": false},
			{"id": "survey_anomaly", "name": "Gravitational Shear", "label": "[ANOMALY] Gravic Drift\nReq: Anchor Card", "locked": false},
			{"id": "survey_cache", "name": "Volatile Isotope Cache", "label": "[PROSPECT] Volatile Cache\nTarget: High Yield", "locked": false}
		]
		
		for data in survey_tokens:
			var btn = Button.new()
			btn.rect_min_size = Vector2(130, 80)
			btn.text = data["label"]
			btn.add_color_override("font_color", Color(0.9, 0.7, 0.3, 1.0))
			btn.connect("pressed", self, "_on_target_token_pressed", [data])
			token_grid.add_child(btn)
