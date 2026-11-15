# Autolevel (Settings "autolevel", the player's ship; MovementSystem adds it): a small roll about the
# nose towards the up nearest the world's, so the ship drifts level without its heading changing (a
# full up-alignment would pitch the nose against the autopilot). Strength: the roll rate that would
# level it in about AUTOLEVEL_TIME (against angular drag), at most AUTOLEVEL_TORQUE_SHARE of the
# ship's turning torque, so steering always wins; none with the nose near straight up or down (no
# level there). Its own script: GUT doubles of MovementSystem cannot override a typed static func.

extends Reference


static func torque(basis: Basis, mass: float, turning_torque: float) -> Vector3:
	var forward: Vector3 = -basis.z.normalized()
	var level_up: Vector3 = Vector3.UP - forward * forward.dot(Vector3.UP)  # The world's up, square to the nose
	if level_up.length_squared() < Constants.AUTOLEVEL_MIN_LEVEL_SQ:
		return Vector3.ZERO  # Nose near straight up or down
	level_up = level_up.normalized()
	var up: Vector3 = basis.y.normalized()
	var roll: float = atan2(up.cross(level_up).dot(forward), up.dot(level_up))  # Signed, about the nose
	var wanted: float = roll / Constants.AUTOLEVEL_TIME * Constants.ANGULAR_DRAG * mass  # Torque holding that roll rate against drag
	var cap: float = turning_torque * Constants.AUTOLEVEL_TORQUE_SHARE
	return forward * clamp(wanted, -cap, cap)
