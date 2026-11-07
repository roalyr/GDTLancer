# AmbientVisuals: a sector scene's node for what is only seen (nebulas, glows, dust: the
# scenes/prefabs/ambient/ prefabs, or anything else). Whatever sits under it is scenery: never solid,
# never a target, never in the way. As each piece enters, its collision layers and masks are
# cleared and it leaves the groups the game finds things by (AMBIENT_STRIPPED_GROUPS: targets,
# obstacles, celestials, rocks), and it casts no shadow. Put it next to SceneAssets in the sector
# scene; CONTENT.md, "Sectors".

extends Spatial

func _ready() -> void:
	add_to_group("ambient_visuals")
	_strip(self)
	get_tree().connect("node_added", self, "_on_node_added")


func _exit_tree() -> void:
	if get_tree().is_connected("node_added", self, "_on_node_added"):
		get_tree().disconnect("node_added", self, "_on_node_added")


# Deferred: a node joins its groups in its own _ready, after it enters the tree.
func _on_node_added(node: Node) -> void:
	if is_a_parent_of(node):
		call_deferred("_strip_later", weakref(node))


func _strip_later(ref: WeakRef) -> void:
	var node = ref.get_ref()
	if node != null and is_a_parent_of(node):
		_strip_one(node)


func _strip(node: Node) -> void:
	_strip_one(node)
	for child in node.get_children():
		_strip(child)


static func _strip_one(node: Node) -> void:
	if node is CollisionObject:
		node.collision_layer = 0
		node.collision_mask = 0
		if node is Area:
			node.monitoring = false
			node.monitorable = false
	if node is GeometryInstance:
		node.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	for group in Constants.AMBIENT_STRIPPED_GROUPS:
		if node.is_in_group(group):
			node.remove_from_group(group)
