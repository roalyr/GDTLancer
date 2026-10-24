# Tests for celestial and station signatures: stars are detected anywhere; planets, moons, asteroids
# and stations within their radius times Constants.SIG_PER_METRE_OF_SIZE, by the ships' rule; a
# station with a beacon anywhere.

extends GutTest

const AgentScript = preload("res://src/core/agents/agent.gd")
const CelestialBodyScript = preload("res://src/scenes/game_world/celestial/celestial_body.gd")
const DockableStationScript = preload("res://src/scenes/game_world/station/dockable_station.gd")
const AsteroidScene = preload("res://scenes/prefabs/celestial/asteroid.tscn")
const PlanetScene = preload("res://scenes/levels/sectors/sector_elace/planet_elace_a/planet_elace_a.tscn")
const StarScene = preload("res://scenes/levels/sectors/sector_elace/star_elace/star_elace.tscn")

var ship: RigidBody = null


func before_each():
	ship = AgentScript.new()
	ship.ship_template = ShipTemplate.new()  # Sensors x1
	add_child_autofree(ship)


func _place(body: Spatial, position: Vector3) -> Spatial:
	add_child_autofree(body)
	body.global_transform.origin = position
	return body


func test_star_is_detected_anywhere():
	var star = _place(StarScene.instance(), Vector3(0, 0, -1e7))
	assert_true(ship.detects(star), "10 000 km away, still shining.")
	assert_true(star.is_in_group("celestial"))


func test_planet_signature_is_its_size_times_the_constant():
	var planet = _place(PlanetScene.instance(), Vector3.ZERO)
	assert_almost_eq(planet.get_apparent_radius(), 1000.0, 0.01, "Planet Elace A: a 1 km collision sphere.")
	var reach: float = 1000.0 * Constants.SIG_PER_METRE_OF_SIZE
	assert_almost_eq(planet.get_signature(), reach, 0.01)
	planet.global_transform.origin = Vector3(0, 0, -reach * 0.9)
	assert_true(ship.detects(planet), "Inside its signature.")
	planet.global_transform.origin = Vector3(0, 0, -reach * 1.1)
	assert_false(ship.detects(planet), "Beyond it: not on the sensors.")
	ship.fit_stats = {"sensor_strength": 1.5, "signature": 1500.0}
	assert_true(ship.detects(planet), "Better sensors reach it.")


func test_scaled_body_grows_its_signature():
	var body = CelestialBodyScript.new()
	var shape_node = CollisionShape.new()
	shape_node.name = "CollisionShape"
	shape_node.shape = SphereShape.new()
	shape_node.shape.radius = 300.0
	body.add_child(shape_node)
	_place(body, Vector3.ZERO)
	body.scale = Vector3.ONE * 2.0
	assert_almost_eq(body.get_signature(), 600.0 * Constants.SIG_PER_METRE_OF_SIZE, 0.01)


func test_asteroid_signature_is_its_size_times_the_constant():
	var rock = AsteroidScene.instance()
	_place(rock, Vector3.ZERO)
	rock.scale = Vector3.ONE * 40.0
	assert_gt(rock.get_apparent_radius(), 1.0)
	assert_almost_eq(rock.get_signature(), rock.get_apparent_radius() * Constants.SIG_PER_METRE_OF_SIZE, 0.01)


func test_station_signature_is_its_size_times_the_constant():
	var station = StaticBody.new()
	station.set_script(DockableStationScript)
	station.obstacle_radius = 110.0
	_place(station, Vector3(0, 0, -110.0 * Constants.SIG_PER_METRE_OF_SIZE * 1.1))
	assert_almost_eq(station.get_signature(), 110.0 * Constants.SIG_PER_METRE_OF_SIZE, 0.01)
	assert_false(ship.detects(station), "A station out past its signature is off the sensors.")
	station.has_beacon = true
	station.global_transform.origin = Vector3(0, 0, -1e7)
	assert_true(ship.detects(station), "One running a beacon is detected anywhere.")


func test_home_station_runs_a_beacon():
	var home = load("res://scenes/levels/sectors/sector_elace/station_elace_home.tscn").instance()
	_place(home, Vector3(0, 0, -1e6))
	assert_true(home.has_beacon)
	assert_true(ship.detects(home), "The way home is always on the sensors.")
