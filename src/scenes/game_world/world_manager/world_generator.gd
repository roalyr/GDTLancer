# WorldGenerator: sets up GameState for a new run from a GameStartTemplate.

extends Node

const DEFAULT_GAME_START_ID = "start_default"
const FALLBACK_SHIP_TEMPLATE_ID = "ship_default"


func generate_new_world(start_template_id: String = DEFAULT_GAME_START_ID) -> void:
	var game_start = TemplateDatabase.game_starts.get(start_template_id)
	if game_start == null:
		printerr("WorldGenerator Warning: Could not find game start template ", start_template_id, ". Using defaults.")
		game_start = GameStartTemplate.new()
		game_start.player_ship_template = FALLBACK_SHIP_TEMPLATE_ID

	GameState.player_ship_template_id = game_start.player_ship_template
	GameState.player_docked_at = game_start.player_starting_location
