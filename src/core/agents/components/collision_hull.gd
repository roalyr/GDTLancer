# CollisionHull: convex collision shapes that follow a model's outline, and where a shot line meets
# a body's shapes.
# - A hull is built from each model's lowest level of detail (MeshLod files; the model itself when
#   it has none): Godot's convex hull of its vertices, cut down to at most
#   Constants.COLLISION_HULL_MAX_POINTS points (the extreme vertex in each of that many directions,
#   so all lie on the hull, spread round it). Points are cached per model file, so every rock or
#   ship of a kind shares the work; each object gets its own shape with its placement and stretch
#   baked into the points.
# - Only .glb model files under the visual root count (engine plumes and effects stay out); a root
#   with none uses its MeshInstances directly.
# - Bullet takes convex shapes on moving bodies well. Never give a RigidBody a concave (trimesh)
#   shape: those are for static bodies only.
# - Hit surfaces: the convex hull can sit metres outside the plating (wing gaps, a rock's hollows),
#   so shots look for a trimesh of each model's first lower level of detail instead, on a
#   StaticBody under the visual root (it moves and stretches with the model). It sits on
#   Constants.HIT_SURFACE_LAYER and collides with nothing; only shot rays look at it. Trimeshes are
#   cached per model file and shared.

extends Reference

const MeshLod = preload("res://src/core/agents/components/mesh_lod.gd")
const _CACHE := {}  # Model file path -> PoolVector3Array of hull points in the model's space
const _SURFACE_CACHE := {}  # Model file path -> ConcavePolygonShape of its hit surface
const HIT_SURFACE_NAME = "HitSurface"


# A convex shape round the models under `visual_root`, with points in the body's space
# (`to_body`: the visual root's placement in the body). Null if no hull could be built.
static func shape_for(visual_root: Node, to_body: Transform) -> Shape:
	var points: PoolVector3Array = _model_points(visual_root, true)
	if points.size() < 4:
		points = _model_points(visual_root, false)
	if points.size() < 4:
		return null
	points = reduce(points, Constants.COLLISION_HULL_MAX_POINTS)
	var placed := PoolVector3Array()
	for point in points:
		placed.append(to_body.xform(point))
	var shape := ConvexPolygonShape.new()
	shape.points = placed
	return shape


# Points of the models under `root`, in root space: from .glb model files (their cached hulls), or
# with `models_only` false from every MeshInstance's own hull.
static func _model_points(root: Node, models_only: bool) -> PoolVector3Array:
	var points := PoolVector3Array()
	var stack: Array = [[root, Transform.IDENTITY]]
	while not stack.empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var to_root: Transform = item[1]
		if models_only and node.filename.ends_with(".glb"):
			if node.filename.find("/lod/") < 0:  # MeshLod's lower levels stand beside the original
				for point in points_for_model(node.filename):
					points.append(to_root.xform(point))
			continue
		if not models_only and node is MeshInstance and node.mesh != null:
			for point in _mesh_points(node.mesh):
				points.append(to_root.xform(point))
		for child in node.get_children():
			if child is Spatial:
				stack.append([child, to_root * child.transform])
	return points


# Hull points of a model file, in its own space, from its lowest level of detail. Cached.
static func points_for_model(model_path: String) -> PoolVector3Array:
	if _CACHE.has(model_path):
		return _CACHE[model_path]
	var lods: Array = MeshLod.lod_paths_for(model_path)
	var scene = load(lods.back() if not lods.empty() else model_path)
	var points := PoolVector3Array()
	if scene is PackedScene:
		var model: Node = scene.instance()
		points = _model_points(model, false)
		model.free()
	points = reduce(points, Constants.COLLISION_HULL_MAX_POINTS)
	_CACHE[model_path] = points
	return points


# The convex hull of a mesh's vertices (Godot computes it), as points.
static func _mesh_points(mesh: Mesh) -> PoolVector3Array:
	var shape = mesh.create_convex_shape()
	return shape.points if shape is ConvexPolygonShape else PoolVector3Array()


# At most `count` of `points`: the extreme one in each of `count` directions spread over a sphere.
# Every point kept lies on the hull, so the hull of what is kept fits inside the original.
static func reduce(points: PoolVector3Array, count: int) -> PoolVector3Array:
	if points.size() <= count:
		return points
	var kept := {}
	var golden: float = PI * (3.0 - sqrt(5.0))
	for i in range(count):
		var y: float = 1.0 - 2.0 * (i + 0.5) / count
		var ring: float = sqrt(max(1.0 - y * y, 0.0))
		var direction := Vector3(cos(golden * i) * ring, y, sin(golden * i) * ring)
		var best := 0
		var best_reach: float = -INF
		for j in range(points.size()):
			var reach: float = points[j].dot(direction)
			if reach > best_reach:
				best_reach = reach
				best = j
		kept[best] = true
	var out := PoolVector3Array()
	for index in kept:
		out.append(points[index])
	return out


# Adds `body`'s hit surface under `visual_root`: a StaticBody with a trimesh of every .glb model
# under it (their first lower level of detail). Returns it, or null if there are no models.
static func add_hit_surface(body: Node, visual_root: Node) -> StaticBody:
	var surface := StaticBody.new()
	surface.name = HIT_SURFACE_NAME
	surface.collision_layer = Constants.HIT_SURFACE_LAYER
	surface.collision_mask = 0
	var stack: Array = [[visual_root, Transform.IDENTITY]]
	while not stack.empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var to_root: Transform = item[1]
		if node.filename.ends_with(".glb"):
			if node.filename.find("/lod/") < 0:
				var shape: Shape = surface_for_model(node.filename)
				if shape != null:
					var holder := CollisionShape.new()
					holder.shape = shape
					holder.transform = to_root
					surface.add_child(holder)
			continue
		for child in node.get_children():
			if child is Spatial:
				stack.append([child, to_root * child.transform])
	if surface.get_child_count() == 0:
		surface.free()
		return null
	visual_root.add_child(surface)
	body.set_meta(HIT_SURFACE_NAME, surface)
	return surface


# The trimesh of a model file's first lower level of detail (the model itself if it has none),
# in the model's space. Cached.
static func surface_for_model(model_path: String) -> Shape:
	if _SURFACE_CACHE.has(model_path):
		return _SURFACE_CACHE[model_path]
	var lods: Array = MeshLod.lod_paths_for(model_path)
	var scene = load(lods.front() if not lods.empty() else model_path)
	var faces := PoolVector3Array()
	if scene is PackedScene:
		var model: Node = scene.instance()
		var stack: Array = [[model, Transform.IDENTITY]]
		while not stack.empty():
			var item: Array = stack.pop_back()
			var node: Node = item[0]
			if node is MeshInstance and node.mesh != null:
				for point in node.mesh.get_faces():
					faces.append(item[1].xform(point))
			for child in node.get_children():
				if child is Spatial:
					stack.append([child, item[1] * child.transform])
		model.free()
	var shape: ConcavePolygonShape = null
	if faces.size() >= 3:
		shape = ConcavePolygonShape.new()
		shape.set_faces(faces)
	_SURFACE_CACHE[model_path] = shape
	return shape


# Where a shot from `from_global` toward `aim_global` meets `body`: its hit surface if it has one
# (nothing if the line passes between its parts), else its collision shapes. The intersect_ray
# result ({position, normal, collider, ...}), or {} if it misses. The ray runs `overshoot` past the
# aim point, and passes through up to Constants.HIT_RAY_PASSES other bodies (the shooter's own hull
# at the start, debris) on the way.
static func ray_onto(body: CollisionObject, from_global: Vector3, aim_global: Vector3, overshoot: float) -> Dictionary:
	if not body.is_inside_tree():
		return {}
	var direction: Vector3 = (aim_global - from_global).normalized()
	if direction == Vector3.ZERO:
		return {}
	var target: CollisionObject = body
	var mask: int = body.collision_layer
	var surface = body.get_meta(HIT_SURFACE_NAME) if body.has_meta(HIT_SURFACE_NAME) else null
	if is_instance_valid(surface) and surface.is_inside_tree():
		target = surface
		mask = Constants.HIT_SURFACE_LAYER
	var space: PhysicsDirectSpaceState = body.get_world().direct_space_state
	var exclude: Array = []
	for _pass in range(Constants.HIT_RAY_PASSES):
		var hit: Dictionary = space.intersect_ray(from_global, aim_global + direction * overshoot, exclude, mask)
		if hit.empty():
			return {}
		if hit.collider == target:
			return hit
		exclude.append(hit.collider)
	return {}
