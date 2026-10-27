# Tests for GameStateManager: new game reset and save/load of GameState.

extends GutTest

const TEST_SLOT = 999


func before_each():
	GameState.reset_state()
	GameStateManager.save_dir = "user://test_savegames/"  # Never the player's real saves


func after_each():
	GameState.reset_state()
	GameStateManager.delete_all_saves()  # Only the test folder
	GameStateManager.save_dir = GameStateManager.SAVE_DIR


func _populate_game_state() -> void:
	GameState.player_ship_template_id = "ship_default"
	GameState.current_sector_id = "sector_cob"
	GameState.player_docked_at = "sector_cob"
	GameState.player_position = Vector3(10, 20, 30)
	GameState.player_rotation = Vector3(0, 90, 0)
	GameState.player_arrived_from_sector = "sector_elace"
	GameState.player_arrival_direction = Vector3(0, 0, -1)


func test_save_and_load_restores_all_fields():
	_populate_game_state()
	assert_true(GameStateManager.save_game(TEST_SLOT), "Game should save successfully.")
	GameState.reset_state()

	assert_true(GameStateManager.load_game(TEST_SLOT), "Game should load successfully.")
	assert_eq(GameState.player_ship_template_id, "ship_default")
	assert_eq(GameState.current_sector_id, "sector_cob")
	assert_eq(GameState.player_docked_at, "sector_cob")
	assert_eq(GameState.player_position, Vector3(10, 20, 30))
	assert_eq(GameState.player_rotation, Vector3(0, 90, 0))
	assert_eq(GameState.player_arrived_from_sector, "sector_elace")
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


func test_save_and_load_restores_hull_scars():
	_populate_game_state()
	var scar: Array = [2.0, 0.0, 0.0, 0.0, 0.7, 0.0, 0.0, 0.0, 2.0, 1.0, 2.0, 3.0, 0.25, 0.9, 2.0]
	GameState.player_hull_scars = [scar]
	GameStateManager.save_game(TEST_SLOT)
	GameState.reset_state()
	assert_eq(GameState.player_hull_scars.size(), 0, "A new game starts with a clean hull.")
	GameStateManager.load_game(TEST_SLOT)
	assert_eq(GameState.player_hull_scars.size(), 1)
	var restored: Array = GameState.player_hull_scars[0]
	assert_eq(restored.size(), 15)
	for i in range(15):
		assert_almost_eq(float(restored[i]), scar[i], 0.0001)


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


func test_losing_the_ship_keeps_the_bank_and_storage_and_wakes_at_home():
	_populate_game_state()
	GameState.home_location_id = "station_elace_home"
	GameState.player_bank = 1234
	GameState.player_storage = {"commodity_tech": 3}
	GameState.player_cargo = {"commodity_scrap": 5}
	GameState.player_fit = {"tools": ["tool_harpoon"]}
	GameState.player_docked_at = ""
	GameStateManager.lose_ship()
	assert_eq(GameState.player_bank, 1234, "The bank is kept")
	assert_eq(GameState.player_storage.get("commodity_tech"), 3, "and the storage")
	assert_eq_deep(GameState.player_cargo, {Constants.FUEL_COMMODITY: Constants.FUEL_STARTING_UNITS})  # The cargo goes with the ship; the new one is fuelled
	assert_true(GameState.player_fit.empty(), "The new ship has its hull's default fit")
	var game_start = TemplateDatabase.game_starts.get(Constants.DEFAULT_GAME_START_ID)
	assert_eq(GameState.player_ship_template_id, game_start.player_ship_template if game_start != null else Constants.FALLBACK_SHIP_TEMPLATE_ID, "The start's ship")
	assert_eq(GameState.player_docked_at, "station_elace_home", "Docked at home")
	assert_eq(GameState.current_sector_id, Constants.INITIAL_SECTOR_ID)


func test_save_carries_the_evolution_and_a_summary():
	_populate_game_state()
	Evolution.new_run()
	var life: Dictionary = Evolution.begin_life("verdant", "1v1")
	Evolution.game_time = 1234.0
	GameState.play_time = 7200.0
	assert_true(GameStateManager.save_game(TEST_SLOT))
	var summary: Dictionary = GameStateManager.get_save_summary(TEST_SLOT)
	assert_almost_eq(float(summary.play_time), 7200.0, 0.01)
	assert_almost_eq(float(summary.game_time), 1234.0, 0.01)
	Evolution.new_run()
	assert_true(GameStateManager.load_game(TEST_SLOT))
	assert_almost_eq(Evolution.game_time, 1234.0, 0.01)
	assert_almost_eq(GameState.play_time, 7200.0, 0.01)
	assert_eq(Evolution.begin_life("verdant", "1v1").uid, life.uid, "The ship flying at the save flies again")
	Evolution.new_run()
	TemplateDatabase.evolved = {}


func test_outdated_saves_are_removed():
	_populate_game_state()
	GameStateManager.save_game(TEST_SLOT)
	var path: String = GameStateManager._get_save_path(TEST_SLOT)
	var file := File.new()
	file.open(path, File.WRITE)
	file.store_var({"player_ship_template_id": "ship_default", "current_sector_id": "sector_cob"}, true)  # No format version
	file.close()
	assert_false(GameStateManager.has_save_file(TEST_SLOT))
	GameStateManager.delete_outdated_saves()
	assert_false(file.file_exists(path))


func test_reset_keeps_the_evolution_only_when_asked():
	Evolution.new_run()
	Evolution.game_time = 50.0
	GameStateManager.keep_evolution = true
	GameStateManager.reset_to_defaults()
	assert_almost_eq(Evolution.game_time, 50.0, 0.01)
	GameStateManager.reset_to_defaults()
	assert_almost_eq(Evolution.game_time, 0.0, 0.01, "The next reset starts it over")
