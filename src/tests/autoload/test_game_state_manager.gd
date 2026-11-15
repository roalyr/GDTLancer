# Tests for GameStateManager: new game reset and save/load of GameState.

extends GutTest

const Fitting = preload("res://src/core/systems/fitting.gd")
const TemplateIndexer = preload("res://src/scenes/game_world/world_manager/template_indexer.gd")
const TEST_SLOT = 999
const TEST_SAVE_DIR = "user://test_savegames/"  # The pre-run hook's: the real folders are never written


func before_each():
	GameState.reset_state()
	GameStateManager.save_dir = TEST_SAVE_DIR  # Never the player's real saves


const DATABASE_KEYS = ["agents", "assets_ships", "assets_modules", "assets_commodities", "locations", "utility_tools", "game_starts", "presets", "preset_agents", "proven_presets"]
var _saved_database: Dictionary = {}


# The game's content in TemplateDatabase (to check a save against), put back as it was after the test.
func _index_content() -> void:
	for key in DATABASE_KEYS:
		_saved_database[key] = TemplateDatabase.get(key).duplicate()
	var indexer = TemplateIndexer.new()
	indexer.index_all_templates()
	indexer.free()


func after_each():
	for key in _saved_database:
		TemplateDatabase.set(key, _saved_database[key])
	_saved_database = {}
	GameState.reset_state()
	GameStateManager.mode = GameStateManager.MODE_PLAY
	GameStateManager.save_dir = TEST_SAVE_DIR  # Set by the mode to the real folder: back to the test one first
	Evolution.frozen = false  # As the pre-run hook leaves it
	GameStateManager.delete_all_saves()  # Only the test folder


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


func test_save_and_load_keeps_worked_rocks():
	_populate_game_state()
	GameState.rock_deposits = {"sector_elace:Layout/Rock_Field_03": [4, 120.5]}
	GameStateManager.save_game(TEST_SLOT)
	GameState.reset_state()
	assert_true(GameState.rock_deposits.empty(), "A new game: every rock full")
	GameStateManager.load_game(TEST_SLOT)
	assert_eq_deep(GameState.rock_deposits, {"sector_elace:Layout/Rock_Field_03": [4, 120.5]})


func test_the_autosave_keeps_to_its_own_slot():
	_populate_game_state()
	GameStateManager.delete_all_saves()
	assert_false(GameStateManager.has_any_save())
	assert_eq(GameStateManager.slot_label(2), "SLOT 2: EMPTY")
	GameState.player_bank = 1200
	assert_true(GameStateManager.save_game(2), "The player's slot")
	GameState.player_bank = 50
	assert_true(GameStateManager.autosave())
	assert_true(GameStateManager.has_save_file(GameStateManager.AUTOSAVE_SLOT))
	assert_false(GameStateManager.AUTOSAVE_SLOT in GameStateManager.manual_slots(), "Never offered for the player's saves")
	assert_eq(GameStateManager.manual_slots().size(), Constants.SAVE_SLOT_COUNT)
	assert_true(GameStateManager.load_game(2))
	assert_eq(GameState.player_bank, 1200, "The autosave left the player's slot alone")
	assert_string_contains(GameStateManager.slot_label(2), "SLOT 2 · COB · 1200 WP")
	assert_string_contains(GameStateManager.slot_label(GameStateManager.AUTOSAVE_SLOT), "AUTOSAVE · COB · 50 WP")
	assert_true(GameStateManager.has_any_save())


func test_the_one_save_from_before_the_slots_is_kept_in_slot_1():
	_populate_game_state()
	GameStateManager.delete_all_saves()
	GameState.player_bank = 777
	GameStateManager.save_game(GameStateManager.AUTOSAVE_SLOT)  # As every save went before the slots
	assert_true(GameStateManager.keep_single_save())
	assert_true(GameStateManager.load_game(1))
	assert_eq(GameState.player_bank, 777, "The old game, in the player's first slot")
	assert_false(GameStateManager.keep_single_save(), "Once: a slot of the player's holds a game now")


func test_a_list_prompt_greys_out_what_cannot_be_picked():
	var PromptDialog = load("res://src/core/ui/helpers/prompt_dialog.gd")
	var prompt = PromptDialog.ask_list(self, "Load game", "", [["0", "AUTOSAVE: EMPTY", true], ["1", "SLOT 1 · COB"], ["cancel", "CANCEL"]])
	var list: Node = prompt.get_node("Center/Frame/Box/List")
	assert_eq(list.get_child_count(), 2, "The slots one under another")
	assert_true(list.get_node("Choice_0").disabled, "An empty slot: shown, not pickable")
	assert_false(list.get_node("Choice_1").disabled)
	assert_not_null(prompt.get_node("Center/Frame/Box/Choices/Choice_cancel"), "Cancel in the row below")
	prompt.free()


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
	GameState.player_fit = {"tools": ["preset_harpoon"]}
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
	var life: Dictionary = Evolution.begin_life("verdant", "arena_verdant_post")
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
	assert_eq(Evolution.begin_life("verdant", "arena_verdant_post").uid, life.uid, "The ship flying at the save flies again")
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


func test_reset_starts_the_world_over():
	Evolution.new_run()
	Evolution.game_time = 50.0
	GameStateManager.reset_to_defaults()
	assert_almost_eq(Evolution.game_time, 0.0, 0.01, "A new game, a new world")


func test_a_save_broken_mid_write_falls_back_to_the_one_before():
	_populate_game_state()
	GameStateManager.save_game(TEST_SLOT)
	GameState.current_sector_id = "sector_elace"
	GameStateManager.save_game(TEST_SLOT)
	var path: String = GameStateManager._get_save_path(TEST_SLOT)
	assert_true(File.new().file_exists(path + GameStateManager.SAVE_BACKUP_EXT), "The save before is kept")
	assert_false(File.new().file_exists(path + GameStateManager.SAVE_TMP_EXT), "Nothing left half-written")
	var file := File.new()
	file.open(path, File.WRITE)  # A power cut halfway through writing it
	file.store_string("garbage")
	file.close()
	GameState.reset_state()
	assert_true(GameStateManager.load_game(TEST_SLOT), "Loads the save before")
	assert_eq(GameState.current_sector_id, "sector_cob")
	GameStateManager.delete_save(TEST_SLOT)
	assert_false(GameStateManager.has_save_file(TEST_SLOT), "Deleted with its backup: it does not come back")


# Switches mode but keeps the test folder (set_mode points save_dir at the mode's real folder).
func _as_mode(mode: String) -> void:
	GameStateManager.mode = mode
	GameStateManager.save_dir = TEST_SAVE_DIR
	Evolution.frozen = false  # As the tests run it (pre-run hook)


func test_each_mode_loads_only_its_own_saves():
	_populate_game_state()
	_as_mode(GameStateManager.MODE_EVOLUTION)
	assert_true(GameStateManager.save_game(TEST_SLOT))
	_as_mode(GameStateManager.MODE_PLAY)
	assert_false(GameStateManager.has_save_file(TEST_SLOT), "The game never sees evolution's save")
	assert_false(GameStateManager.load_game(TEST_SLOT), "nor loads it")
	GameStateManager.delete_outdated_saves()
	assert_true(File.new().file_exists(GameStateManager._get_save_path(TEST_SLOT)), "and never deletes it either")
	GameStateManager.delete_all_saves()  # (In one folder the play save's backup would be evolution's)
	assert_true(GameStateManager.save_game(TEST_SLOT))
	_as_mode(GameStateManager.MODE_EVOLUTION)
	assert_false(GameStateManager.has_save_file(TEST_SLOT), "Evolution never sees the game's")
	_as_mode(GameStateManager.MODE_PLAY)
	assert_true(GameStateManager.has_save_file(TEST_SLOT), "The game sees its own")


func test_a_save_from_before_the_modes_is_evolutions():
	_populate_game_state()
	assert_true(GameStateManager.save_game(TEST_SLOT))
	var path: String = GameStateManager._get_save_path(TEST_SLOT)
	var file := File.new()
	file.open(path, File.READ)
	var data: Dictionary = file.get_var(true)
	file.close()
	data.erase("mode")  # As every save was before
	file.open(path, File.WRITE)
	file.store_var(data, true)
	file.close()
	assert_false(GameStateManager.has_save_file(TEST_SLOT), "Not the game's")
	_as_mode(GameStateManager.MODE_EVOLUTION)
	assert_true(GameStateManager.has_save_file(TEST_SLOT), "but evolution's")
	_as_mode(GameStateManager.MODE_PLAY)


func test_the_modes_keep_their_data_in_their_own_folders():
	GameStateManager.mode = GameStateManager.MODE_EVOLUTION
	assert_eq(GameStateManager.save_dir, Constants.EVOLUTION_DIR)
	assert_false(Evolution.frozen, "Evolution evolves")
	GameStateManager.mode = GameStateManager.MODE_PLAY
	assert_eq(GameStateManager.save_dir, GameStateManager.PLAY_SAVE_DIR)
	assert_true(Evolution.frozen, "the game flies presets")
	assert_true(Constants.EVO_LOG_DIR.begins_with(Constants.EVOLUTION_DIR), "Life logs are evolution's")
	assert_true(Constants.EVOLUTION_BACKUPS_DIR.begins_with(Constants.EVOLUTION_DIR))
	_as_mode(GameStateManager.MODE_PLAY)


func test_a_test_start_plays_its_start_and_saves_apart():
	var saved_mode: String = GameStateManager.mode
	GameStateManager.test_start_id = "start_custom"
	GameStateManager.mode = GameStateManager.MODE_PLAY
	var start: String = GameStateManager.game_start_id()
	var dir: String = GameStateManager.save_dir
	GameStateManager.mode = GameStateManager.MODE_EVOLUTION
	var evolution_start: String = GameStateManager.game_start_id()
	GameStateManager.test_start_id = ""
	GameStateManager.mode = saved_mode
	GameStateManager.save_dir = TEST_SAVE_DIR
	assert_eq(start, "start_custom")
	assert_eq(dir, GameStateManager.TEST_SAVE_DIR, "Never the real saves")
	assert_eq(evolution_start, Constants.EVO_GAME_START_ID, "Evolution keeps its own")


func test_evolution_runs_in_its_own_sector_and_an_old_save_moves_there():
	var saved_mode: String = GameStateManager.mode
	assert_eq([GameStateManager.game_start_id(), GameStateManager.home_sector_id()], [Constants.DEFAULT_GAME_START_ID, Constants.INITIAL_SECTOR_ID], "The game: its home")
	GameStateManager.mode = GameStateManager.MODE_EVOLUTION
	GameStateManager.save_dir = TEST_SAVE_DIR
	assert_eq([GameStateManager.game_start_id(), GameStateManager.home_sector_id()], [Constants.EVO_GAME_START_ID, Constants.EVO_SECTOR_ID], "Evolution: the arena")
	GameState.current_sector_id = Constants.INITIAL_SECTOR_ID  # Where evolution lived before
	GameState.player_docked_at = "station_elace_home"
	GameStateManager._rehome_in_arena()
	assert_eq(GameStateManager.game_start(Constants.EVO_GAME_START_ID).player_starting_location, "station_arena_home")
	assert_eq([GameState.current_sector_id, GameState.player_docked_at, GameState.home_location_id],
		[Constants.EVO_SECTOR_ID, GameStateManager.game_start(Constants.EVO_GAME_START_ID).player_starting_location,
		GameStateManager.game_start(Constants.EVO_GAME_START_ID).player_starting_location])
	GameStateManager.mode = saved_mode
	GameStateManager.save_dir = TEST_SAVE_DIR


# A save from an older build names content that is gone since: it loads into a game that plays.
func test_a_save_naming_content_gone_since_is_put_right():
	_index_content()
	var start = GameStateManager.game_start(GameStateManager.game_start_id())
	_populate_game_state()
	GameState.player_ship_template_id = "ship_gone_since"
	GameState.home_location_id = "station_gone_since"
	GameState.player_storage = {"tool_gone_since": 2, Fitting.catalog()[0]: 1}
	GameState.player_cargo = {"commodity_gone_since": 3, "commodity_scrap": 2}
	GameState.player_standing = {"faction_gone_since": 0.5}
	GameState.station_markups = {"station_gone_since": 0.2}
	GameStateManager.save_game(TEST_SLOT)
	GameState.reset_state()
	assert_true(GameStateManager.load_game(TEST_SLOT), "It still loads")
	assert_eq(GameState.player_ship_template_id, start.player_ship_template, "The start's ship")
	assert_eq(GameState.home_location_id, start.player_starting_location, "The start's home")
	assert_eq_deep(GameState.player_storage, {Fitting.catalog()[0]: 1})
	assert_eq_deep(GameState.player_cargo, {"commodity_scrap": 2})
	assert_true(GameState.player_standing.empty() and GameState.station_markups.empty(), "Stale keys dropped")
	assert_eq(GameStateManager.repair_notes.size(), 4, "Ship, home, a part, cargo: each told: %s" % [GameStateManager.repair_notes])


func test_a_save_of_the_current_content_needs_no_repair():
	_index_content()
	var start = GameStateManager.game_start(GameStateManager.game_start_id())
	_populate_game_state()
	GameState.player_ship_template_id = start.player_ship_template
	GameState.home_location_id = start.player_starting_location
	GameState.player_cargo = {Constants.FUEL_COMMODITY: 2}
	GameState.player_fit = {"tools": [Fitting.catalog()[0]], "modules": []}
	GameStateManager.save_game(TEST_SLOT)
	GameState.reset_state()
	GameStateManager.load_game(TEST_SLOT)
	assert_eq(GameStateManager.repair_notes, [], "Nothing to put right")
	assert_eq(GameState.player_fit.tools, [Fitting.catalog()[0]], "The fit as saved")
