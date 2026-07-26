# PROJECT: GDTLancer
# MODULE: board_ui_station.gd
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
		board_title_label.text = "STATION TABLETOP INTERFACE"
		
	# Populate Station Facilities & Resident NPCs
	if token_grid != null:
		for child in token_grid.get_children():
			child.queue_free()
			
		var station_tokens: Array = [
			{"id": "facility_comms", "name": "Comms Relay", "label": "[FACILITY] Comms Relay\nTarget: Sensor Check", "locked": false},
			{"id": "facility_workshop", "name": "Dockside Workshop", "label": "[FACILITY] Workshop Bay\nTarget: Repair Check", "locked": false},
			{"id": "node_outer_margin_alpha", "name": "Outer Margin Vault", "label": "[LOCKED VAULT] Outer Margin\nReq: Nav-Pass", "locked": true},
			{"id": "npc_vera", "name": "Master Vera", "label": "[NPC] Master Vera\nBond: STABLE | Stewardship", "locked": false},
			{"id": "npc_kael", "name": "Trader Kael", "label": "[NPC] Trader Kael\nBond: FRAGILE | Depletion", "locked": false},
			{"id": "npc_jax", "name": "Tech Jax", "label": "[NPC] Tech Jax\nBond: DEEP | Maintenance", "locked": false}
		]
		
		for data in station_tokens:
			var btn = Button.new()
			btn.rect_min_size = Vector2(130, 80)
			btn.text = data["label"]
			if data["locked"]:
				btn.hint_tooltip = "Mechanically Locked: Requires Outer Margin Nav-Pass Asset Card"
				btn.add_color_override("font_color", Color(0.9, 0.4, 0.4, 1.0))
			elif data["id"].begins_with("npc_"):
				btn.add_color_override("font_color", Color(0.4, 1.0, 0.6, 1.0))
			else:
				btn.add_color_override("font_color", Color(0.4, 0.8, 1.0, 1.0))
			btn.connect("pressed", self, "_on_target_token_pressed", [data])
			token_grid.add_child(btn)
