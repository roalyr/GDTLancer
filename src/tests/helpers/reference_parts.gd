# Reference part genes for the law and weapon tests: fixed numbers the tests' expectations are worked
# out from (the old type seeds), so tuning the part catalogue (PartCatalog) never moves them.

extends Reference

const GENES = {
	"laser": {1: {"mass": 150.0, "energy": 2.5}, 2: {"mass": 300.0, "energy": 5.0}, 3: {"mass": 600.0, "energy": 12.0}},
	"plating": {1: {"mass": 500.0}, 2: {"mass": 1000.0}, 3: {"mass": 2000.0}},
	"thruster": {1: {"mass": 200.0}, 2: {"mass": 400.0}, 3: {"mass": 800.0}},
	"power_cell": {1: {"mass": 150.0}, 2: {"mass": 300.0}, 3: {"mass": 600.0}},
	"lance": {1: {"nail_mass": 100.0, "count": 3.0}, 2: {"nail_mass": 200.0, "count": 3.0}, 3: {"nail_mass": 350.0, "count": 4.0}},
	"missile": {1: {"round_mass": 40.0, "count": 4.0}, 2: {"round_mass": 100.0, "count": 4.0}, 3: {"round_mass": 250.0, "count": 4.0}},
	"cannon": {1: {"mass": 150.0, "round_mass": 2.0, "count": 80.0}, 2: {"mass": 300.0, "round_mass": 5.0, "count": 60.0}, 3: {"mass": 700.0, "round_mass": 15.0, "count": 40.0}},
	"sensor": {1: {"mass": 120.0}, 2: {"mass": 250.0}, 3: {"mass": 500.0}},
	"damper": {1: {"mass": 150.0}, 2: {"mass": 300.0}, 3: {"mass": 600.0}},
	"decoy": {1: {"mass": 100.0}, 2: {"mass": 200.0}, 3: {"mass": 400.0}},
	"afterburner": {1: {"mass": 200.0}, 2: {"mass": 400.0}, 3: {"mass": 800.0}},
	"magazine": {1: {"mass": 100.0}, 2: {"mass": 200.0}, 3: {"mass": 400.0}},
	"rack": {1: {"mass": 150.0}, 2: {"mass": 300.0}, 3: {"mass": 600.0}},
}


static func genes(kind: String, part_type: int) -> Dictionary:
	return GENES[kind][part_type].duplicate()
