extends "res://addons/gut/test.gd"

var NpcTradePanelScene = load("res://scenes/ui/menus/npc_trade_panel/NpcTradePanel.tscn")

func before_each():
	GameState.reset_state()

func test_panel_opens_on_signal():
	var panel = NpcTradePanelScene.instance()
	add_child_autofree(panel)
	
	# Start hidden
	assert_false(panel.visible, "Panel should start hidden")
	
	# Create dummy target and state
	var target = Spatial.new()
	target.name = "test_agent"
	add_child_autofree(target)
	
	GameState.agents["test_agent"] = {"agent_role": "trader"}
	
	EventBus.emit_signal("player_npc_interact_requested", "test_agent", target)
	
	assert_true(panel.visible, "Panel should be visible after signal")
	assert_eq(panel._current_agent_id, "test_agent", "Panel should track agent id")
	
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


class FakeCharacterSystem:
	var credits = {}
	func get_credits(uid): return credits.get(uid, 0)
	func add_credits(uid, amt): credits[uid] = get_credits(uid) + amt
	func subtract_credits(uid, amt): credits[uid] = get_credits(uid) - amt

class FakeInventorySystem:
	var inv = {}
	func get_asset_count(uid, type, id):
		if not inv.has(uid): return 0
		return inv[uid].get(id, 0)
	func get_inventory_by_type(uid, type):
		return inv.get(uid, {})
	func add_asset(uid, type, id, qty=1):
		if not inv.has(uid): inv[uid] = {}
		inv[uid][id] = get_asset_count(uid, type, id) + qty
	func remove_asset(uid, type, id, qty=1):
		if not inv.has(uid): inv[uid] = {}
		inv[uid][id] = max(0, get_asset_count(uid, type, id) - qty)

class FakeAgentLayer:
	func _resolve_payment_instrument(payer, payee):
		return "credits"
		
class FakeSimulationEngine:
	var agent_layer = FakeAgentLayer.new()

func test_trade_buy_execution_mutates_state():
	var panel = NpcTradePanelScene.instance()
	add_child_autofree(panel)
	
	var fake_char = FakeCharacterSystem.new()
	var fake_inv = FakeInventorySystem.new()
	var fake_sim = FakeSimulationEngine.new()
	GlobalRefs.character_system = fake_char
	GlobalRefs.inventory_system = fake_inv
	GlobalRefs.simulation_engine = fake_sim
	
	var player_uid = int(GameState.player_character_uid)
	fake_char.credits[player_uid] = 1000
	fake_char.credits[999] = 100
	
	GameState.agents["test_npc"] = {
		"character_uid": 999,
		"cargo_commodity_id": "commodity_fuel",
		"tags": ["FACTION_TRADERS"]
	}
	
	panel._current_agent_id = "test_npc"
	panel._refresh_ui()
	
	panel._on_BtnBuyCargo_pressed()
	
	assert_eq(fake_inv.get_asset_count(player_uid, 2, "commodity_fuel"), 1, "Player should get fuel")
	assert_true(fake_char.get_credits(player_uid) < 1000, "Player should spend credits")
	assert_eq(GameState.pending_sim_mutations.size(), 1, "Mutation should be enqueued")
