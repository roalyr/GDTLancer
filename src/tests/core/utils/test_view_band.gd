# Tests for ViewBand and ViewDetail: view bands from apparent size, zoom included, and a host's band
# that everything on it follows.

extends GutTest

const ViewBand = preload("res://src/core/utils/view_band.gd")
const ViewDetail = preload("res://src/core/agents/components/view_detail.gd")


func _camera(fov: float) -> Camera:
	var camera = Camera.new()
	camera.fov = fov
	add_child_autofree(camera)
	camera.current = true
	return camera


func test_screen_share_is_the_diameter_over_the_view_height():
	var camera = _camera(90.0)  # tan(45) = 1: the view is 2 m tall per metre of distance
	assert_almost_eq(ViewBand.screen_share(camera, Vector3(0, 0, -100), 10.0), 0.1, 0.0001)


func test_bands_from_share_with_hysteresis():
	var shares: Array = Constants.VIEW_BAND_SHARES
	assert_eq(ViewBand.band_for(1.0), Constants.VIEW_CLOSE)
	assert_eq(ViewBand.band_for(0.0), Constants.VIEW_DOT)
	assert_eq(ViewBand.band_for(shares[Constants.VIEW_MID] * 1.5), Constants.VIEW_MID)
	var just_below: float = shares[Constants.VIEW_MID] * 0.95
	assert_eq(ViewBand.band_for(just_below, Constants.VIEW_MID), Constants.VIEW_MID, "Shown in MID: holds just below")
	assert_eq(ViewBand.band_for(just_below, Constants.VIEW_FAR), Constants.VIEW_FAR, "coming from FAR: stays until clearly above.")
	for k in range(100):
		var share: float = 0.5 * pow(0.9, k)
		assert_true(ViewBand.band_for(share * 0.9) >= ViewBand.band_for(share), "Smaller never means a nearer band.")


func test_zooming_in_brings_far_objects_near():
	var wide = _camera(70.0)
	var far_ship := Vector3(0, 0, -15000)
	assert_eq(ViewBand.band_of(wide, far_ship, 15.0), Constants.VIEW_DOT, "15 km out at 70 degrees: a dot")
	var narrow = _camera(6.0)  # Constants.CAMERA_TELEPHOTO_MIN_FOV_DEG
	assert_true(ViewBand.band_of(narrow, far_ship, 15.0) <= Constants.HULL_SCAR_MAX_BAND, "at full zoom it shows its scars.")


func test_distance_leaving_matches_the_band():
	var camera = _camera(70.0)
	var edge: float = ViewBand.distance_leaving(Constants.VIEW_MID, 15.0, 70.0)
	assert_eq(ViewBand.band_of(camera, Vector3(0, 0, -edge * 0.8), 15.0), Constants.VIEW_MID)
	assert_eq(ViewBand.band_of(camera, Vector3(0, 0, -edge * 1.3), 15.0), Constants.VIEW_FAR)


func test_host_band_updates_on_a_zoom_without_waiting():
	var camera = _camera(70.0)
	var host = Spatial.new()
	add_child_autofree(host)
	host.translation = Vector3(0, 0, -15000)
	var detail = ViewDetail.attach(host, 15.0)
	detail._timer = 0.0
	detail._process(0.0)
	assert_eq(detail.band, Constants.VIEW_DOT)
	detail._timer = 100.0  # Not due for a check
	camera.fov = 6.0
	detail._process(0.0)
	assert_true(detail.band < Constants.VIEW_DOT, "A field of view change is judged at once.")


func test_things_on_a_host_find_its_band():
	var host = Spatial.new()
	add_child_autofree(host)
	var detail = ViewDetail.attach(host, 10.0)
	var child = Spatial.new()
	host.add_child(child)
	var grandchild = Spatial.new()
	child.add_child(grandchild)
	detail.band = Constants.VIEW_FAR
	assert_eq(ViewDetail.band_of_host(grandchild), Constants.VIEW_FAR)
	assert_eq(ViewDetail.band_of_host(Spatial.new()), Constants.VIEW_CLOSE, "No host: everything shown.")
