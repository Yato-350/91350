extends GutTest

const REQUIRED: Array[String] = [
	"noir",
	"blanc",
	"beton_1",
	"beton_2",
	"beton_3",
	"beton_4",
	"beton_5",
	"bleu_nuit",
	"orange_sodium",
	"rouge_propagande",
]


func test_palette_fits_in_32_colors() -> void:
	assert_between(Palette.load_colors().size(), REQUIRED.size() + 8, Palette.MAX_COLORS)


func test_required_colors_exist() -> void:
	var colors := Palette.load_colors()
	for id: String in REQUIRED:
		assert_has(colors, id)


func test_colors_match_the_file() -> void:
	var colors := Palette.load_colors()
	assert_eq(colors["rouge_propagande"], Color("#c8202c"))


func test_concrete_ramp_goes_from_dark_to_light() -> void:
	var colors := Palette.load_colors()
	for step: int in range(1, 5):
		var darker: Color = colors["beton_%d" % step]
		var lighter: Color = colors["beton_%d" % (step + 1)]
		assert_lt(darker.get_luminance(), lighter.get_luminance())


func test_missing_file_gives_empty_palette() -> void:
	assert_eq(Palette.load_colors("res://absent.json"), {})
	assert_push_error("absent.json")
