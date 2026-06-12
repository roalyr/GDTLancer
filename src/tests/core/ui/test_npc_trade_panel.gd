##
## PROJECT: GDTLancer
## MODULE: test_npc_trade_panel.gd
## STATUS: [Level 2 - Implementation]
## TRUTH_LINK: gameplay_milestone_audit.md
## LOG_REF: 2026-06-12 23:00:00
##

extends "res://addons/gut/test.gd"

var NpcTradePanelScene = load("res://scenes/ui/menus/npc_trade_panel/NpcTradePanel.tscn")

func before_each():
	GameState.reset_state()

func test_panel_remains_hidden_as_deprecated():
	var panel = NpcTradePanelScene.instance()
	add_child_autofree(panel)
	
	# Start hidden
	assert_false(panel.visible, "Panel should start hidden")
	
	# Create dummy target and state
	var target = Spatial.new()
	target.name = "test_agent"
	add_child_autofree(target)
	
	GameState.agents["test_agent"] = {"agent_role": "trader"}
	
	# Attempt to open for agent
	panel.open_for_agent("test_agent", target)
	
	assert_false(panel.visible, "Panel should remain hidden as standalone trading is deprecated.")
	assert_eq(panel._current_agent_id, "test_agent", "Panel should still track agent id internally.")
	
func test_panel_closes_on_button():
	var panel = NpcTradePanelScene.instance()
	add_child_autofree(panel)
	
	panel.visible = true
	panel._on_BtnClose_pressed()
	
	assert_false(panel.visible, "Panel should close on button press")

func test_panel_auto_closes_if_target_invalid():
	var panel = NpcTradePanelScene.instance()
	add_child_autofree(panel)
	
	var target = Spatial.new()
	add_child_autofree(target)
	
	panel._current_target = target
	panel.visible = true
	
	# simulate process
	panel._process(0.1)
	assert_true(panel.visible, "Panel remains open if target is valid")
	
	target.free()
	
	panel._process(0.1)
	assert_false(panel.visible, "Panel closes if target becomes invalid")
