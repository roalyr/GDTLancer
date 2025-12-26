extends "res://addons/gut/test.gd"

# Unit tests for NarrativeStatusPanel
# Path: tests/src/core/ui/narrative_status/test_narrative_status_panel.gd

const NarrativeStatusPanelScene = preload("res://scenes/ui/screens/narrative_status_panel.tscn")

var _panel = null

func before_each():
	_panel = NarrativeStatusPanelScene.instance()
	add_child(_panel)

func after_each():
	_panel.free()

func test_initial_visibility():
	assert_false(_panel.visible, "Panel should be hidden by default")

func test_update_reputation():
	# Backup
	var old_rep = GameState.narrative_state.get("reputation", 0)
	
	GameState.narrative_state["reputation"] = 88
	_panel.update_display()
	
	assert_eq(_panel.reputation_label.text, "Reputation: 88")
	
	# Restore
	GameState.narrative_state["reputation"] = old_rep

func test_update_stats():
	# Backup
	var old_stats = GameState.session_stats.duplicate()
	
	GameState.session_stats["contracts_completed"] = 12
	GameState.session_stats["total_wp_earned"] = 5000
	GameState.session_stats["enemies_disabled"] = 7
	
	_panel.update_display()
	
	var expected_text = "Contracts Completed: 12\nTotal WP Earned: 5000\nCombat Victories: 7"
	assert_eq(_panel.contracts_label.text, expected_text)
	
	# Restore
	GameState.session_stats = old_stats

func test_close_button_hides_panel():
	_panel.show()
	assert_true(_panel.visible)
	
	_panel._on_ButtonClose_pressed()
	assert_false(_panel.visible, "Panel should be hidden after close pressed")

func test_quirks_display():
	# Mock QuirkSystem
	var mock_qs = Node.new()
	mock_qs.name = "MockQuirkSystem"
	# We need a dummy method get_quirks
	mock_qs.set_script(load("res://src/core/systems/quirk_system.gd")) 
	# Note: This might still fail if QuirkSystem refers to GameState, but get_quirks is safe-ish.
	
	var old_qs = GlobalRefs.quirk_system
	GlobalRefs.quirk_system = mock_qs
	
	# Setup test data
	var ship_uid = 123
	GameState.player_character_uid = 1
	GameState.characters[1] = {"active_ship_uid": ship_uid}
	GameState.assets_ships[ship_uid] = {"ship_quirks": ["fast", "fragile"]}
	
	_panel.show()
	_panel.update_display()
	
	# Should have 2 children in quirks_container (Labels)
	assert_eq(_panel.quirks_container.get_child_count(), 2, "Should display 2 quirks")
	
	# Cleanup
	GlobalRefs.quirk_system = old_qs
	mock_qs.free()

func test_reacts_to_wp_change_signal():
	_panel.show() # Must be visible to update
	var old_stats = GameState.session_stats.duplicate()
	
	GameState.session_stats["total_wp_earned"] = 999
	_panel._on_player_wp_changed(999) # Call handler directly to avoid EventBus issues in test
	
	assert_true(_panel.contracts_label.text.find("Earned: 999") != -1, "Should contain updated WP value")
	
	GameState.session_stats = old_stats
