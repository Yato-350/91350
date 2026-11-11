extends GutTest

const SCALE_CASES: Array = [
	[Vector2i(1280, 720), 2],
	[Vector2i(1920, 1080), 3],
	[Vector2i(3840, 2160), 6],
	[Vector2i(1366, 768), 2],
	[Vector2i(640, 360), 1],
	[Vector2i(320, 200), 1],
	[Vector2i(2560, 1080), 3],
	[Vector2i(1080, 1920), 1],
]
const LOW_RES_CASES: Array = [
	[Vector2i(1920, 1080), 3, Vector2i(640, 360)],
	[Vector2i(1366, 768), 2, Vector2i(683, 384)],
	[Vector2i(2560, 1080), 3, Vector2i(854, 360)],
	[Vector2i(320, 200), 1, Vector2i(320, 200)],
]
const SAMPLE := Vector3(3.37, 12.11, -7.93)
const EPSILON := 0.0001

var _iso := Basis.from_euler(Vector3(deg_to_rad(-30.0), deg_to_rad(45.0), 0.0))


func test_integer_scale(params: Array = use_parameters(SCALE_CASES)) -> void:
	assert_eq(PixelSnap.integer_scale(params[0]), params[1])


func test_low_res_size(params: Array = use_parameters(LOW_RES_CASES)) -> void:
	assert_eq(PixelSnap.low_res_size(params[0], params[1]), params[2])


func test_snapped_position_lies_on_the_grid() -> void:
	var snapped := PixelSnap.snap_position(SAMPLE, _iso, PixelSnap.TEXEL)
	var local := snapped * _iso
	assert_almost_eq(fposmod(local.x + EPSILON, PixelSnap.TEXEL), EPSILON, EPSILON)
	assert_almost_eq(fposmod(local.y + EPSILON, PixelSnap.TEXEL), EPSILON, EPSILON)
	assert_almost_eq(local.z, (SAMPLE * _iso).z, EPSILON)


func test_offset_stays_within_half_a_pixel() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91350
	for i: int in 50:
		var position := Vector3(
			rng.randf_range(-99, 99), rng.randf_range(0, 30), rng.randf_range(-99, 99)
		)
		var snapped := PixelSnap.snap_position(position, _iso, PixelSnap.TEXEL)
		var offset := PixelSnap.display_offset(position, snapped, _iso, PixelSnap.TEXEL)
		assert_lte(absf(offset.x), 0.5 + EPSILON)
		assert_lte(absf(offset.y), 0.5 + EPSILON)


func test_position_on_the_grid_has_no_offset() -> void:
	var snapped := PixelSnap.snap_position(SAMPLE, _iso, PixelSnap.TEXEL)
	var offset := PixelSnap.display_offset(snapped, snapped, _iso, PixelSnap.TEXEL)
	assert_almost_eq(offset, Vector2.ZERO, Vector2.ONE * EPSILON)


func test_offset_signs() -> void:
	var snapped := PixelSnap.snap_position(SAMPLE, _iso, PixelSnap.TEXEL)
	var right := snapped + _iso.x * 0.25 * PixelSnap.TEXEL
	var up := snapped + _iso.y * 0.25 * PixelSnap.TEXEL
	var right_offset := PixelSnap.display_offset(right, snapped, _iso, PixelSnap.TEXEL)
	var up_offset := PixelSnap.display_offset(up, snapped, _iso, PixelSnap.TEXEL)
	assert_almost_eq(right_offset, Vector2(-0.25, 0.0), Vector2.ONE * 0.001)
	assert_almost_eq(up_offset, Vector2(0.0, 0.25), Vector2.ONE * 0.001)


func test_moving_one_texel_moves_the_snap_not_the_offset() -> void:
	var moved := SAMPLE + _iso.x * PixelSnap.TEXEL
	var snapped := PixelSnap.snap_position(SAMPLE, _iso, PixelSnap.TEXEL)
	var moved_snapped := PixelSnap.snap_position(moved, _iso, PixelSnap.TEXEL)
	var offset := PixelSnap.display_offset(SAMPLE, snapped, _iso, PixelSnap.TEXEL)
	var moved_offset := PixelSnap.display_offset(moved, moved_snapped, _iso, PixelSnap.TEXEL)
	assert_almost_eq(moved_snapped, snapped + _iso.x * PixelSnap.TEXEL, Vector3.ONE * EPSILON)
	assert_almost_eq(moved_offset, offset, Vector2.ONE * EPSILON)
