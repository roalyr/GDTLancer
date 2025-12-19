# mock_ship_template.gd
# Test helper that mimics ShipTemplate properties without extending Resource
extends Resource

var hull_integrity: int = 100
var armor_integrity: int = 50


func _init(hull: int = 100, armor: int = 50):
	hull_integrity = hull
	armor_integrity = armor
	
	# Check for meta overrides (used by tests)
	if has_meta("hull_integrity"):
		hull_integrity = get_meta("hull_integrity")
	if has_meta("armor_integrity"):
		armor_integrity = get_meta("armor_integrity")
