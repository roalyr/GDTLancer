# Tests for AssetSystem ship template lookup.

extends GutTest

const AssetSystem = preload("res://src/core/systems/asset_system.gd")
const ShipTemplate = preload("res://database/definitions/asset_ship_template.gd")

const TEST_SHIP_ID = "ship_test_asset_system"

var asset_system_instance = null
var _ship_template = null


func before_each():
	_ship_template = ShipTemplate.new()
	_ship_template.template_id = TEST_SHIP_ID
	TemplateDatabase.assets_ships[TEST_SHIP_ID] = _ship_template
	asset_system_instance = AssetSystem.new()
	add_child_autofree(asset_system_instance)


func after_each():
	TemplateDatabase.assets_ships.erase(TEST_SHIP_ID)
	GameState.player_ship_template_id = ""
	GlobalRefs.asset_system = null


func test_registers_in_global_refs():
	assert_eq(GlobalRefs.asset_system, asset_system_instance)


func test_get_ship_template_by_id():
	assert_eq(asset_system_instance.get_ship_template(TEST_SHIP_ID), _ship_template)


func test_get_ship_template_unknown_or_empty_id_returns_null():
	assert_null(asset_system_instance.get_ship_template("ship_does_not_exist"))
	assert_null(asset_system_instance.get_ship_template(""))


func test_get_player_ship_template_follows_game_state():
	assert_null(asset_system_instance.get_player_ship_template(), "No player ship before a run starts.")
	GameState.player_ship_template_id = TEST_SHIP_ID
	assert_eq(asset_system_instance.get_player_ship_template(), _ship_template)
