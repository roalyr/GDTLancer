#
# PROJECT: GDTLancer
# MODULE: world_generator.gd
# STATUS: Level 3 - Verified
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md (Section 7 Platform Mechanics Divergence)
# LOG_REF: 2026-01-28-QA-Intern
#

extends Node

## WorldGenerator: Creates initial game state including characters, ships, locations, and contracts.
## Populates GameState dictionaries from TemplateDatabase resources.

const InventorySystem = preload("res://src/core/systems/inventory_system.gd")

var _next_character_uid: int = 0
var _next_ship_uid: int = 0
var _next_module_uid: int = 0
# Commodity UIDs are no longer needed as they are not unique instances.

# --- Public API ---

# Main entry point. Generates all necessary data for a new game.
func generate_new_world():
	print("WorldGenerator: Generating new world state...")

	# Load all locations into GameState first (they are keyed by template_id).
	_load_locations()
	
	# Load all contracts into GameState.
	_load_contracts()

	_load_factions()
	# DEPRECATED: ContactTemplate system replaced by Persistent Agents.
	# _load_contacts() (See TACTICAL_TODO Task 12)

	# Create characters first.
	for template_id in TemplateDatabase.characters:
		var template = TemplateDatabase.characters[template_id]
		_create_character_from_template(template)

	# Then, generate and assign their starting assets and inventories.
	_generate_and_assign_assets()

	# Sprint 10: Start player docked at Station Alpha, with defined starting resources.
	GameState.player_docked_at = "station_alpha"
	_apply_player_starting_state()
	call_deferred("_emit_initial_dock_signal")

	print("WorldGenerator: New world state generated.")


func _apply_player_starting_state() -> void:
	var player_uid: int = int(GameState.player_character_uid)
	if player_uid < 0:
		return
	if GameState.characters.has(player_uid):
		var player_char = GameState.characters[player_uid]
		player_char.credits = 50
		player_char.focus_points = 3
		if EventBus:
			EventBus.emit_signal("player_credits_changed", player_char.credits)
			EventBus.emit_signal("player_fp_changed", player_char.focus_points)

	# Starting cargo should be empty for the player.
	if GameState.inventories.has(player_uid):
		var inv = GameState.inventories[player_uid]
		if inv is Dictionary and inv.has(InventorySystem.InventoryType.COMMODITY):
			inv[InventorySystem.InventoryType.COMMODITY] = {}


func _emit_initial_dock_signal() -> void:
	# Wait until the player agent exists and the zone is loaded, then dock.
	var retries := 0
	while retries < 30 and (not is_instance_valid(GlobalRefs.current_zone) or not is_instance_valid(GlobalRefs.player_agent_body)):
		yield(get_tree().create_timer(0.1), "timeout")
		retries += 1

	if GameState.player_docked_at == "":
		return

	# Move the player agent to the docked station position (so they truly spawn there).
	var dock_id: String = GameState.player_docked_at
	if is_instance_valid(GlobalRefs.player_agent_body):
		var dock_pos = _get_dock_position_in_zone(dock_id)
		if dock_pos != null:
			var spawn_pos: Vector3 = dock_pos + Vector3(0, 5, 15)
			var t: Transform = GlobalRefs.player_agent_body.global_transform
			t.origin = spawn_pos
			GlobalRefs.player_agent_body.global_transform = t

	if EventBus:
		EventBus.emit_signal("player_docked", GameState.player_docked_at)


func _get_dock_position_in_zone(location_id: String):
	if location_id == "":
		return null
	if is_instance_valid(GlobalRefs.current_zone):
		var stations = get_tree().get_nodes_in_group("dockable_station")
		for station in stations:
			if not is_instance_valid(station):
				continue
			if not (station is Spatial):
				continue
			if not GlobalRefs.current_zone.is_a_parent_of(station):
				continue
			if station.get("location_id") == location_id:
				return station.global_transform.origin

	if GameState.locations.has(location_id):
		var loc = GameState.locations[location_id]
		if loc and loc.get("position_in_zone") is Vector3:
			return loc.position_in_zone

	return null


# --- Private Logic ---

# Loads all location templates into GameState.locations.
# Locations are stored directly by their template_id (they don't have UIDs).
func _load_locations():
	print("WorldGenerator: Loading locations...")
	for template_id in TemplateDatabase.locations:
		var template = TemplateDatabase.locations[template_id]
		# Duplicate to allow runtime modifications (e.g., market price fluctuation).
		GameState.locations[template_id] = template.duplicate()
		print("... Loaded location: ", template.location_name)


# Loads all contract templates into GameState.contracts.
# Contracts are stored by their template_id (available pool).
func _load_contracts():
	print("WorldGenerator: Loading contracts...")
	for template_id in TemplateDatabase.contracts:
		var template = TemplateDatabase.contracts[template_id]
		# Duplicate to allow runtime state tracking.
		GameState.contracts[template_id] = template.duplicate()
		print("... Loaded contract: ", template.title)


func _load_factions():
	print("WorldGenerator: Loading factions...")
	for template_id in TemplateDatabase.factions:
		var template = TemplateDatabase.factions[template_id]
		GameState.factions[template_id] = template.duplicate()
		
		# Seed initial standing
		if not GameState.narrative_state.faction_standings.has(template.faction_id):
			GameState.narrative_state.faction_standings[template.faction_id] = template.default_standing


func _load_contacts():
	print("WorldGenerator: Loading contacts...")
	for template_id in TemplateDatabase.contacts:
		var template = TemplateDatabase.contacts[template_id]
		GameState.contacts[template_id] = template.duplicate()
		
		# Seed initial relationship
		if not GameState.narrative_state.contact_relationships.has(template.contact_id):
			GameState.narrative_state.contact_relationships[template.contact_id] = template.initial_relationship


# Creates a unique instance of a character from a template and registers it
# in the global GameState. It also creates their inventory.
func _create_character_from_template(template: CharacterTemplate):
	var new_character_instance = template.duplicate()
	var uid = _get_new_character_uid()

	# Populate the GameState with the new character.
	GameState.characters[uid] = new_character_instance

	# --- NEW: Create an inventory record for this character ---
	if is_instance_valid(GlobalRefs.inventory_system):
		GlobalRefs.inventory_system.create_inventory_for_character(uid)
	# --- END NEW ---

	# Designate the player character.
	if template.template_id == "character_default":
		GameState.player_character_uid = uid
		print("... Player character created with UID: ", uid)
	else:
		print("... NPC character created with UID: ", uid)


# Generates starting assets and assigns them to characters using the InventorySystem.
func _generate_and_assign_assets():
	print("WorldGenerator: Generating and assigning starting assets...")
	for char_uid in GameState.characters:
		var character = GameState.characters[char_uid]
		
		# Create and assign a starting ship.
		var ship_uid = _create_ship_instance("ship_default")
		if ship_uid != -1:
			# Add the ship to the character's inventory.
			GlobalRefs.inventory_system.add_asset(char_uid, GlobalRefs.inventory_system.InventoryType.SHIP, ship_uid)
			# Set this ship as the character's active vessel.
			character.active_ship_uid = ship_uid
			print("... Assigned ship (UID: %d) to character %s" % [ship_uid, character.character_name])

		# Create and assign a starting module.
		var module_uid = _create_module_instance("module_default")
		if module_uid != -1:
			GlobalRefs.inventory_system.add_asset(char_uid, GlobalRefs.inventory_system.InventoryType.MODULE, module_uid)
			print("... Assigned module (UID: %d) to character %s" % [module_uid, character.character_name])
			
		# Sprint 10: Player starting cargo should be empty.
		# (NPC starting cargo can be added later if needed for simulation.)


# Creates a unique instance of a ship and returns its UID.
func _create_ship_instance(ship_template_id: String) -> int:
	if not TemplateDatabase.assets_ships.has(ship_template_id):
		printerr("WorldGenerator Error: Cannot find ship template with id: ", ship_template_id)
		return -1

	var template = TemplateDatabase.assets_ships[ship_template_id]
	var new_ship_instance = template.duplicate()
	var uid = _get_new_ship_uid()
	GameState.assets_ships[uid] = new_ship_instance
	return uid


# Creates a unique instance of a module and returns its UID.
func _create_module_instance(module_template_id: String) -> int:
	if not TemplateDatabase.assets_modules.has(module_template_id):
		printerr("WorldGenerator Error: Cannot find module template with id: ", module_template_id)
		return -1
		
	var template = TemplateDatabase.assets_modules[module_template_id]
	var new_module_instance = template.duplicate()
	var uid = _get_new_module_uid()
	GameState.assets_modules[uid] = new_module_instance
	return uid


# --- UID Generation ---
func _get_new_character_uid() -> int:
	var id = _next_character_uid
	_next_character_uid += 1
	return id

func _get_new_ship_uid() -> int:
	var id = _next_ship_uid
	_next_ship_uid += 1
	return id

func _get_new_module_uid() -> int:
	var id = _next_module_uid
	_next_module_uid += 1
	return id
