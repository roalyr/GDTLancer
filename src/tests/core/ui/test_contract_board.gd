##
## PROJECT: GDTLancer
## MODULE: test_contract_board.gd
## STATUS: [Level 2 - Implementation]
## TRUTH_LINK: 1-GDD-Core-Mechanics.md § 6.1
## LOG_REF: 2026-06-14 01:00:09
##

extends "res://addons/gut/test.gd"

var ContractBoardScene = load("res://scenes/ui/menus/contract_board/ContractBoard.tscn")


class FakeSimulationEngine:
	extends Reference

	var accept_calls: Array = []

	func player_accept_runtime_contract(occurrence_id: String) -> bool:
		accept_calls.append(occurrence_id)
		GameState.player_claimed_occurrence_id = occurrence_id
		var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
		if occurrence.empty():
			return false
		occurrence["claimant_agent_id"] = "player"
		occurrence["status"] = "claimed"
		occurrence["source_reserved"] = true
		occurrence["payment_reserved"] = true
		occurrence["cargo_picked_up"] = false
		GameState.runtime_contract_occurrences[occurrence_id] = occurrence
		return true

	func player_pick_up_runtime_contract(_occurrence_id: String) -> bool:
		return false

	func player_complete_runtime_contract(_occurrence_id: String) -> bool:
		return false


func before_each() -> void:
	_seed_state()


func after_each() -> void:
	GlobalRefs.simulation_engine = null
	GameState.current_sector_id = ""
	GameState.player_claimed_occurrence_id = ""
	GameState.player_cargo_tag = "EMPTY"
	GameState.sector_names.clear()
	GameState.sector_tags.clear()
	GameState.sector_disabled_until.clear()
	GameState.sim_tick_count = 0
	GameState.agents.clear()
	GameState.runtime_contract_occurrences.clear()
	GameState.contract_cargo_supply.clear()
	GameState.contract_cargo_reserved.clear()
	GameState.contract_payment_supply.clear()
	GameState.contract_payment_reserved.clear()


func test_contract_board_lists_player_displayable_occurrences() -> void:
	GameState.runtime_contract_occurrences = {
		"runtime_contract:s2:RAW": _make_occurrence("runtime_contract:s2:RAW", true),
		"runtime_contract:s3:RAW": _make_occurrence("runtime_contract:s3:RAW", false),
	}

	var contract_board = ContractBoardScene.instance()
	add_child_autofree(contract_board)
	contract_board.show_board()
	yield(get_tree(), "idle_frame")

	var contract_list: VBoxContainer = contract_board.get_node("Panel/VBoxContainer/ContractScroll/ContractList")
	assert_eq(contract_list.get_child_count(), 1,
		"ContractBoard should list only player-displayable runtime occurrences.")


func test_contract_board_accept_button_routes_to_simulation_engine() -> void:
	GameState.runtime_contract_occurrences = {
		"runtime_contract:s2:RAW": _make_occurrence("runtime_contract:s2:RAW", true),
	}
	GlobalRefs.simulation_engine = FakeSimulationEngine.new()

	var contract_board = ContractBoardScene.instance()
	add_child_autofree(contract_board)
	contract_board.show_board()
	yield(get_tree(), "idle_frame")

	var contract_list: VBoxContainer = contract_board.get_node("Panel/VBoxContainer/ContractScroll/ContractList")
	var row: VBoxContainer = contract_list.get_child(0)
	var accept_button: Button = row.get_node("ButtonRow/AcceptButton")
	accept_button.emit_signal("pressed")
	yield(get_tree(), "idle_frame")

	var engine: FakeSimulationEngine = GlobalRefs.simulation_engine
	assert_eq(engine.accept_calls, ["runtime_contract:s2:RAW"],
		"ContractBoard Accept should route through the simulation engine helper.")
	assert_eq(GameState.player_claimed_occurrence_id, "runtime_contract:s2:RAW",
		"Accept should update the shared player claim state.")


func test_contract_board_gates_pickup_and_complete_buttons_by_player_state() -> void:
	GameState.runtime_contract_occurrences = {
		"runtime_contract:s2:RAW": _make_occurrence("runtime_contract:s2:RAW", true),
	}
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["claimant_agent_id"] = "player"
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["status"] = "claimed"
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["source_reserved"] = true
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["payment_reserved"] = true
	GameState.player_claimed_occurrence_id = "runtime_contract:s2:RAW"

	var contract_board = ContractBoardScene.instance()
	add_child_autofree(contract_board)
	contract_board.show_board()
	yield(get_tree(), "idle_frame")

	var contract_list: VBoxContainer = contract_board.get_node("Panel/VBoxContainer/ContractScroll/ContractList")
	var row: VBoxContainer = contract_list.get_child(0)
	var entry_label: Label = row.get_node("EntryLabel")
	var pickup_button: Button = row.get_node("ButtonRow/PickupButton")
	var complete_button: Button = row.get_node("ButtonRow/CompleteButton")
	assert_true(entry_label.text.find("Backing: source reserved, payment reserved, cargo not picked up") != -1,
		"ContractBoard rows should expose reservation and pickup state for debug use.")
	assert_false(pickup_button.disabled,
		"Pick Up should be enabled when the player is in the source sector with a claimed empty-cargo contract.")
	assert_true(complete_button.disabled,
		"Complete should stay disabled before cargo is picked up and the player reaches the target sector.")

	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["source_reserved"] = false
	contract_board.show_board()
	yield(get_tree(), "idle_frame")

	contract_list = contract_board.get_node("Panel/VBoxContainer/ContractScroll/ContractList")
	row = contract_list.get_child(0)
	pickup_button = row.get_node("ButtonRow/PickupButton")
	assert_true(pickup_button.disabled,
		"Pick Up should stay disabled when the claimed contract has no live source-side reservation.")

	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["source_reserved"] = true
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["cargo_picked_up"] = true
	GameState.current_sector_id = "s2"
	GameState.agents["player"]["current_sector_id"] = "s2"
	GameState.player_cargo_tag = "LOADED"
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["status"] = "in_transit"
	contract_board.show_board()
	yield(get_tree(), "idle_frame")

	contract_list = contract_board.get_node("Panel/VBoxContainer/ContractScroll/ContractList")
	row = contract_list.get_child(0)
	pickup_button = row.get_node("ButtonRow/PickupButton")
	complete_button = row.get_node("ButtonRow/CompleteButton")
	assert_true(pickup_button.disabled,
		"Pick Up should disable once the player is already carrying contract cargo.")
	assert_false(complete_button.disabled,
		"Complete should enable when the player reaches the target sector with loaded cargo.")


func test_contract_board_blocks_pickup_while_source_sector_is_disabled() -> void:
	GameState.runtime_contract_occurrences = {
		"runtime_contract:s2:RAW": _make_occurrence("runtime_contract:s2:RAW", true),
	}
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["claimant_agent_id"] = "player"
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["status"] = "claimed"
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["source_reserved"] = true
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["payment_reserved"] = true
	GameState.player_claimed_occurrence_id = "runtime_contract:s2:RAW"
	GameState.sector_tags["s1"] = ["STATION", "SECURE", "MILD", "DISABLED"]

	var contract_board = ContractBoardScene.instance()
	add_child_autofree(contract_board)
	contract_board.show_board()
	yield(get_tree(), "idle_frame")

	var contract_list: VBoxContainer = contract_board.get_node("Panel/VBoxContainer/ContractScroll/ContractList")
	var row: VBoxContainer = contract_list.get_child(0)
	var entry_label: Label = row.get_node("EntryLabel")
	var pickup_button: Button = row.get_node("ButtonRow/PickupButton")

	assert_true(pickup_button.disabled,
		"Pick Up should stay disabled while the source sector is disabled.")
	assert_true(entry_label.text.find("waiting for source recovery") != -1,
		"ContractBoard should surface that the contract is waiting for source recovery.")
	assert_true(entry_label.text.find("Next: Waiting for source recovery at Source") != -1,
		"ContractBoard should provide a source-recovery specific next-step hint.")


func test_contract_board_blocks_completion_while_target_sector_is_disabled() -> void:
	GameState.runtime_contract_occurrences = {
		"runtime_contract:s2:RAW": _make_occurrence("runtime_contract:s2:RAW", true),
	}
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["claimant_agent_id"] = "player"
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["status"] = "in_transit"
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["cargo_picked_up"] = true
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["payment_reserved"] = true
	GameState.player_claimed_occurrence_id = "runtime_contract:s2:RAW"
	GameState.player_cargo_tag = "LOADED"
	GameState.current_sector_id = "s2"
	GameState.agents["player"]["current_sector_id"] = "s2"
	GameState.sector_tags["s2"] = ["STATION", "CONTESTED", "MILD", "DISABLED"]

	var contract_board = ContractBoardScene.instance()
	add_child_autofree(contract_board)
	contract_board.show_board()
	yield(get_tree(), "idle_frame")

	var contract_list: VBoxContainer = contract_board.get_node("Panel/VBoxContainer/ContractScroll/ContractList")
	var row: VBoxContainer = contract_list.get_child(0)
	var entry_label: Label = row.get_node("EntryLabel")
	var complete_button: Button = row.get_node("ButtonRow/CompleteButton")

	assert_true(complete_button.disabled,
		"Complete should stay disabled while the target sector is disabled.")
	assert_true(entry_label.text.find("waiting for target recovery") != -1,
		"ContractBoard should surface that the contract is waiting for target recovery.")
	assert_true(entry_label.text.find("Next: Waiting for target recovery at Target") != -1,
		"ContractBoard should provide a target-recovery specific next-step hint.")


func _seed_state() -> void:
	GameState.current_sector_id = "s1"
	GameState.player_claimed_occurrence_id = ""
	GameState.player_cargo_tag = "EMPTY"
	GameState.sim_tick_count = 0
	GameState.sector_names = {
		"s1": "Source",
		"s2": "Target",
	}
	GameState.sector_tags = {
		"s1": ["STATION", "SECURE", "MILD"],
		"s2": ["STATION", "CONTESTED", "MILD"],
	}
	GameState.sector_disabled_until.clear()
	GameState.agents = {
		"player": {
			"current_sector_id": "s1",
			"cargo_tag": "EMPTY",
		}
	}
	GameState.runtime_contract_occurrences.clear()


func _make_occurrence(occurrence_id: String, player_displayable: bool) -> Dictionary:
	return {
		"occurrence_id": occurrence_id,
		"source_sector_id": "s1",
		"target_sector_id": "s2",
		"required_cargo_tag": "RAW_COMMODITY",
		"contract_value_class": "Mid",
		"status": "open",
		"claimant_agent_id": "",
		"source_reserved": false,
		"payment_reserved": false,
		"cargo_picked_up": false,
		"player_displayable": player_displayable,
	}
