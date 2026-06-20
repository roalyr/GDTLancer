# PROJECT: GDTLancer
# MODULE: test_chronicle_view_transitions.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: GDD-MASTER-DESIGN-DIRECTIVE.md §2; TRUTH_GAME-LOOP-VISION.md §5
# LOG_REF: 2026-06-20 19:52:00

extends "res://addons/gut/test.gd"

var MainHUDScene = load("res://scenes/ui/hud/main_hud.tscn")

var _hud_instance: Control = null
var _original_mouse_mode: int = Input.MOUSE_MODE_VISIBLE

func before_each() -> void:
	_original_mouse_mode = Input.get_mouse_mode()
	get_tree().paused = false
	GameState.current_ui_mode = "MODE_A"
	
	_hud_instance = MainHUDScene.instance()
	add_child_autofree(_hud_instance)

func after_each() -> void:
	if is_instance_valid(_hud_instance):
		_hud_instance.queue_free()
	get_tree().paused = false
	Input.set_mouse_mode(_original_mouse_mode)
	GameState.current_ui_mode = "MODE_A"

func test_set_ui_mode_to_mode_b_pauses_gameplay_and_shows_mouse() -> void:
	assert_eq(GameState.current_ui_mode, "MODE_A", "Starts in MODE_A.")
	assert_false(get_tree().paused, "Starts unpaused.")
	
	# Transition to Mode B
	_hud_instance.set_ui_mode("MODE_B")
	
	assert_eq(GameState.current_ui_mode, "MODE_B", "Transitions state to MODE_B.")
	assert_true(get_tree().paused, "Pauses the SceneTree.")
	assert_eq(Input.get_mouse_mode(), Input.MOUSE_MODE_VISIBLE, "Sets mouse mode to visible.")

func test_set_ui_mode_to_mode_a_unpauses_gameplay() -> void:
	_hud_instance.set_ui_mode("MODE_B")
	assert_true(get_tree().paused, "Pauses SceneTree.")
	
	# Transition to Mode A
	_hud_instance.set_ui_mode("MODE_A")
	
	assert_eq(GameState.current_ui_mode, "MODE_A", "Transitions state to MODE_A.")
	assert_false(get_tree().paused, "Unpauses the SceneTree.")

func test_mode_b_hides_flight_hud_elements() -> void:
	var screen_controls: Control = _hud_instance.get_node_or_null("ScreenControls")
	var target_overlay: Control = _hud_instance.get_node_or_null("ProjectedTargetOverlay")
	
	# Default visible
	if is_instance_valid(screen_controls):
		assert_true(screen_controls.visible, "ScreenControls visible in Mode A.")
	if is_instance_valid(target_overlay):
		assert_true(target_overlay.visible, "Target overlay visible in Mode A.")
		
	# Transition to Mode B
	_hud_instance.set_ui_mode("MODE_B")
	
	if is_instance_valid(screen_controls):
		assert_false(screen_controls.visible, "ScreenControls hidden in Mode B.")
	if is_instance_valid(target_overlay):
		assert_false(target_overlay.visible, "Target overlay hidden in Mode B.")

func test_npc_interaction_requested_triggers_transition_to_mode_b() -> void:
	var target = Spatial.new()
	add_child_autofree(target)
	
	assert_eq(GameState.current_ui_mode, "MODE_A", "Starts in Mode A.")
	
	EventBus.emit_signal("player_npc_interact_requested", "ada_agent", target)
	
	assert_eq(GameState.current_ui_mode, "MODE_B", "Signal interaction requested transitions UI mode to Mode B.")
	assert_true(get_tree().paused, "Pauses simulation clock on interaction request.")

func test_closing_interaction_window_restores_mode_a() -> void:
	# Trigger interaction
	var target = Spatial.new()
	add_child_autofree(target)
	EventBus.emit_signal("player_npc_interact_requested", "ada_agent", target)
	assert_eq(GameState.current_ui_mode, "MODE_B")
	
	# Close interaction window
	var window = _hud_instance.get_node_or_null("InteractionWindow")
	assert_not_null(window, "InteractionWindow exists.")
	if is_instance_valid(window):
		window.close()
		
	assert_eq(GameState.current_ui_mode, "MODE_A", "Closing InteractionWindow triggers transition back to Mode A.")
	assert_false(get_tree().paused, "Simulation clock unpauses.")
