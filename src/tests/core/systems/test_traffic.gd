# Tests for Traffic: the travellers' roster and their off-screen timetable (dwell, jump with fuel,
# arrive, restock in Elace), and replacements for lost ones.

extends GutTest

const Traffic = preload("res://src/core/systems/traffic.gd")

var traffic: Node = null
var _saved_locations: Dictionary = {}


func before_each():
	_saved_locations = TemplateDatabase.locations
	TemplateDatabase.locations = {}
	for id in ["sector_elace", "sector_cob", "sector_lywin", "sector_vidr"]:
		TemplateDatabase.locations[id] = load("res://database/registry/locations/%s.tres" % id)
	GameState.reset_state()
	GameState.current_sector_id = "sector_vidr"  # Elace is off-screen: nothing spawns
	traffic = Traffic.new()
	add_child_autofree(traffic)


func after_each():
	GameState.reset_state()
	TemplateDatabase.locations = _saved_locations


func test_the_roster_fills_in_elace_fuelled():
	traffic.fill_roster()
	assert_eq(GameState.travelers.size(), Traffic._roster_size())
	for record in GameState.travelers:
		assert_eq(record.sector, Constants.INITIAL_SECTOR_ID)
		assert_eq(int(record.fuel), Traffic.jump_cost(record) * Constants.TRAFFIC_FUEL_JUMPS)
		assert_true(record.next in Traffic.neighbours_of(record.sector))
		assert_true(record.genome.has("ship"))


func test_a_traveller_jumps_burning_fuel_and_arrives_after_its_transit():
	traffic.fill_roster()
	var record: Dictionary = GameState.travelers[0]
	var fuel: int = int(record.fuel)
	var next: String = record.next
	GameState.world_time = float(record.until) + 1.0
	traffic.tick()
	assert_eq(record.status, "transit")
	assert_eq(record.sector, next)
	assert_eq(int(record.fuel), fuel - Traffic.jump_cost(record))
	GameState.world_time += Constants.TRAFFIC_TRANSIT_TIME + 1.0
	traffic.tick()
	assert_eq(record.status, "dwell")
	assert_gt(float(record.until), GameState.world_time)


func test_without_fuel_it_stays_and_in_elace_it_sells_and_refuels():
	traffic.fill_roster()
	var record: Dictionary = GameState.travelers[0]
	record.sector = "sector_cob"
	record.next = Constants.INITIAL_SECTOR_ID
	record.fuel = 0
	GameState.world_time = float(record.until) + 1.0
	traffic.tick()
	assert_eq(record.status, "dwell", "No fuel: no jump")
	assert_eq(record.sector, "sector_cob")
	record.fuel = Traffic.jump_cost(record)
	record.cargo = {"commodity_ore": 4}
	var bank: float = float(record.bank)
	GameState.world_time = float(record.until) + 1.0
	traffic.tick()  # Leaves
	GameState.world_time += Constants.TRAFFIC_TRANSIT_TIME + 1.0
	traffic.tick()  # Arrives in Elace
	assert_eq(record.sector, Constants.INITIAL_SECTOR_ID)
	assert_eq(record.status, "dwell")
	assert_true(record.cargo.empty(), "Sold in Elace")
	assert_gt(int(record.fuel), 0, "Refuelled")
	assert_ne(float(record.bank), bank)


func test_a_lost_travellers_place_is_filled_only_when_its_replacement_is_due():
	traffic.fill_roster()
	GameState.travelers.remove(0)
	GameState.traffic_replacements.append(GameState.world_time + Constants.TRAFFIC_REPLACE_TIME)
	traffic.fill_roster()
	assert_eq(GameState.travelers.size(), Traffic._roster_size() - 1)
	GameState.world_time += Constants.TRAFFIC_REPLACE_TIME + 1.0
	traffic.fill_roster()
	assert_eq(GameState.travelers.size(), Traffic._roster_size())
