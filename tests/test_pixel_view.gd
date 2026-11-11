extends GutTest

const SCENE := preload("res://scenes/main/pixel_view.tscn")
const LAYOUT_CASES: Array = [
	[Vector2(1280, 720), 2, Vector2i(642, 362)],
	[Vector2(1920, 1080), 3, Vector2i(642, 362)],
	[Vector2(1366, 768), 2, Vector2i(685, 386)],
	[Vector2(320, 200), 1, Vector2i(322, 202)],
]
const SAMPLE := Vector3(3.37, 12.11, -7.93)
const EPSILON := 0.0001


func test_layout(params: Array = use_parameters(LAYOUT_CASES)) -> void:
	var view := _make_view(params[0])
	await wait_process_frames(2)
	assert_eq(view.get_pixel_scale(), params[1])
	assert_eq(view.get_world_viewport().size, params[2])


func test_resizing_updates_the_scale() -> void:
	var view := _make_view()
	watch_signals(view)
	view.size = Vector2(1920, 1080)
	assert_signal_emitted_with_parameters(view, "scale_changed", [3])


func test_camera_is_snapped_and_sized() -> void:
	var view := _make_view()
	var camera := _add_camera(view)
	await wait_process_frames(2)
	var local := camera.global_position * camera.global_basis
	assert_almost_eq(fposmod(local.x + EPSILON, PixelSnap.TEXEL), EPSILON, EPSILON)
	assert_almost_eq(fposmod(local.y + EPSILON, PixelSnap.TEXEL), EPSILON, EPSILON)
	assert_almost_eq(camera.size, view.get_world_viewport().size.y / 16.0, 0.001)


func test_container_follows_the_subpixel_offset() -> void:
	var view := _make_view()
	var camera := _add_camera(view)
	await wait_process_frames(2)
	camera.global_position = SAMPLE
	var snapped := PixelSnap.snap_position(SAMPLE, camera.global_basis, PixelSnap.TEXEL)
	var offset := PixelSnap.display_offset(SAMPLE, snapped, camera.global_basis, PixelSnap.TEXEL)
	view._process(0.0)
	var pixel_scale := view.get_pixel_scale()
	var base := -Vector2.ONE * PixelSnap.MARGIN * pixel_scale
	var container: Control = view.get_node("Container")
	assert_eq(container.position, base + (offset * pixel_scale).round())
	assert_ne(container.position, base, "le cas choisi doit avoir un décalage non nul")


func test_view_without_camera_has_no_offset() -> void:
	var view := _make_view()
	await wait_process_frames(2)
	var container: Control = view.get_node("Container")
	assert_eq(container.position, -Vector2.ONE * PixelSnap.MARGIN * view.get_pixel_scale())


func test_saturation_request_is_applied() -> void:
	var view := _make_view()
	EventBus.saturation_change_requested.emit(0.0, 0.0)
	await wait_process_frames(1)
	assert_eq(view.saturation, 0.0)


func test_palette_is_sent_to_the_shader() -> void:
	var view := _make_view()
	assert_eq(view.get_palette_size(), Palette.load_colors().size())


func test_missing_palette_disables_the_grade_pass() -> void:
	var view: PixelView = SCENE.instantiate()
	view.palette_path = "res://absent.json"
	add_child_autofree(view)
	assert_eq(view.get_palette_size(), 0)
	assert_push_error("absent.json")


func test_set_zone_replaces_the_previous_zone() -> void:
	var view := _make_view()
	var first := Node3D.new()
	var second := Node3D.new()
	view.set_zone(first)
	view.set_zone(second)
	await wait_process_frames(2)
	assert_eq(view.get_zone(), second)
	assert_false(is_instance_valid(first))


func _make_view(view_size: Vector2 = Vector2(1280, 720)) -> PixelView:
	var view: PixelView = SCENE.instantiate()
	add_child_autofree(view)
	view.size = view_size
	return view


func _add_camera(view: PixelView) -> Camera3D:
	var zone := Node3D.new()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(-30.0, 45.0, 0.0)
	camera.position = SAMPLE
	zone.add_child(camera)
	view.set_zone(zone)
	camera.make_current()
	return camera
