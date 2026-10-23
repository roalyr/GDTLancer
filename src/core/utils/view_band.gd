# ViewBand: how detailed something should be drawn, from how large it looks. An object's screen
# share is the part of the screen height its diameter covers from a camera, zoom (field of view)
# included; its band is the first of Constants.VIEW_BAND_SHARES it reaches (VIEW_CLOSE .. VIEW_FAR),
# else VIEW_DOT. Hysteresis (Constants.VIEW_BAND_HYSTERESIS) keeps the band it has until the share
# is clearly past a threshold. See the VIEW DETAIL section of Constants.

extends Reference


# Part of the screen height a sphere of `radius` at `point` covers from `camera`.
static func screen_share(camera: Camera, point: Vector3, radius: float) -> float:
	if camera.projection == Camera.PROJECTION_ORTHOGONAL:
		return radius * 2.0 / max(camera.size, 0.001)
	var distance: float = camera.global_transform.origin.distance_to(point)
	return radius / max(distance * tan(deg2rad(camera.fov) * 0.5), 0.001)


# The band for `share`, given the band `current` shown now (Constants.VIEW_DOT for something new).
static func band_for(share: float, current: int = Constants.VIEW_DOT) -> int:
	var shares: Array = Constants.VIEW_BAND_SHARES
	for band in range(shares.size()):
		var keep: bool = current <= band  # Already this detailed: hold until clearly below
		var threshold: float = shares[band] * ((1.0 - Constants.VIEW_BAND_HYSTERESIS) if keep else (1.0 + Constants.VIEW_BAND_HYSTERESIS))
		if share >= threshold:
			return band
	return Constants.VIEW_DOT


# The band of a sphere of `radius` at `point` from `camera`, judged afresh (loose effects).
static func band_of(camera: Camera, point: Vector3, radius: float) -> int:
	return band_for(screen_share(camera, point, radius))


# How far from a camera of field of view `fov_deg` a sphere of `radius` leaves `band` (for tuning
# and tests; hysteresis aside).
static func distance_leaving(band: int, radius: float, fov_deg: float) -> float:
	if band >= Constants.VIEW_BAND_SHARES.size():
		return INF
	return radius / (Constants.VIEW_BAND_SHARES[band] * tan(deg2rad(fov_deg) * 0.5))
