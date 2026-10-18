# Tests for GameStateManager: new game reset and save/load of GameState.

extends GutTest

const TEST_SLOT = 999


func before_each():
	GameState.reset_state()


func after_each():
	GameState.reset_state()
	var dir = Directory.new()
	var save_path = GameStateManager._get_save_path(TEST_SLOT)
	if dir.file_exists(save_path):
		dir.remove(save_path)


func _populate_game_state() -> void:
	GameState.player_ship_template_id = "ship_default"
	GameState.current_sector_id = "sector_star_cob"
	GameState.player_docked_at = "sector_star_cob"
	GameState.player_position = Vector3(10, 20, 30)
	GameState.player_rotation = Vector3(0, 90, 0)
	GameState.player_arrived_from_sector = "sector_star_elace"
	GameState.player_arrival_direction = Vector3(0, 0, -1)


func test_save_and_load_restores_all_fields():
	_populate_game_state()
	assert_true(GameStateManager.save_game(TEST_SLOT), "Game should save successfully.")
	GameState.reset_state()

	assert_true(GameStateManager.load_game(TEST_SLOT), "Game should load successfully.")
	assert_eq(GameState.player_ship_template_id, "ship_default")
	assert_eq(GameState.current_sector_id, "sector_star_cob")
	assert_eq(GameState.player_docked_at, "sector_star_cob")
	assert_eq(GameState.player_position, Vector3(10, 20, 30))
	assert_eq(GameState.player_rotation, Vector3(0, 90, 0))
	assert_eq(GameState.player_arrived_from_sector, "sector_star_elace")
	assert_eq(GameState.player_arrival_direction, Vector3(0, 0, -1))


func test_save_and_load_restores_hull_and_cargo():
	_populate_game_state()
	GameState.player_hull = 42.5
	GameState.player_cargo = {"commodity_scrap": 7, "commodity_tech": 1}
	GameStateManager.save_game(TEST_SLOT)
	GameState.reset_state()
	GameStateManager.load_game(TEST_SLOT)
	assert_almost_eq(GameState.player_hull, 42.5, 0.001)
	assert_eq_deep(GameState.player_cargo, {"commodity_scrap": 7, "commodity_tech": 1})


func test_save_and_load_restores_hull_marks():
	_populate_game_state()
	GameState.player_hull_marks = {"0:0": PoolRealArray([1.0, 0.4, 0.75])}
	GameStateManager.save_game(TEST_SLOT)
	GameState.reset_state()
	assert_eq(GameState.player_hull_marks.size(), 0, "A new game starts with a clean hull.")
	GameStateManager.load_game(TEST_SLOT)
	var restored: PoolRealArray = GameState.player_hull_marks["0:0"]
	assert_eq(restored.size(), 3)
	for i in range(3):
		assert_almost_eq(restored[i], [1.0, 0.4, 0.75][i], 0.0001)


func test_load_emits_game_state_loaded():
	_populate_game_state()
	GameStateManager.save_game(TEST_SLOT)
	watch_signals(EventBus)
	GameStateManager.load_game(TEST_SLOT)
	assert_signal_emitted(EventBus, "game_state_loaded")


func test_has_save_file_false_when_missing():
	assert_false(GameStateManager.has_save_file(TEST_SLOT), "Missing save should not be offered.")
	assert_false(GameStateManager.load_game(TEST_SLOT), "Loading a missing save should fail.")


func test_has_save_file_false_for_save_without_ship():
	_populate_game_state()
	GameState.player_ship_template_id = ""
	GameStateManager.save_game(TEST_SLOT)
	assert_false(GameStateManager.has_save_file(TEST_SLOT), "A save without a ship cannot restore a run.")


func test_reset_to_defaults_clears_state():
	_populate_game_state()
	GameStateManager.reset_to_defaults()
	assert_eq(GameState.player_ship_template_id, "")
	assert_eq(GameState.current_sector_id, "")
	assert_eq(GameState.player_docked_at, "")
	assert_eq(GameState.player_position, Vector3.ZERO)
	assert_eq(GameState.player_arrival_direction, Vector3.ZERO)
