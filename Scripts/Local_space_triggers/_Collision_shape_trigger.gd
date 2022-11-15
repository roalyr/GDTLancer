extends Area

onready var p = get_tree().get_root().get_node("Main/Paths")

func _ready():
	disable_collisions()

func disable_collisions():
	for child in get_parent().get_children():
		if child is CollisionShape:
			child.disabled = true
			print("Collision disabled for shape: ", child)

func enable_collisions():
	for child in get_parent().get_children():
		if child is CollisionShape:
			child.disabled = false
			print("Collision enabled for shape: ", child)

# SIGNAL PROCESSING
func _on_Area_body_entered(_body):
	if _body == p.ship: 
		enable_collisions()


func _on_Area_body_exited(_body):
	if _body == p.ship: 
		disable_collisions()
