class_name DayLight
## La lumière selon l'heure, en logique pure : soleil (énergie, couleur, direction),
## ambiance (énergie, couleur) et fond. Des repères horaires, interpolés entre eux.
## Le soleil se lève à l'est, passe au sud et se couche à l'ouest.

const NIGHT_BACKGROUND := Color(0.0706, 0.102, 0.1804)
const DAWN_BACKGROUND := Color(0.169, 0.247, 0.4)
## La nuit reste lisible : une lumière de lune bleutée.
const NIGHT_AMBIENT := Color(0.34, 0.4, 0.66)
const DAY_AMBIENT := Color(0.62, 0.66, 0.8)
const DAY_SUN := Color(0.95, 0.96, 1.0)
## [heure, énergie du soleil, couleur du soleil, énergie d'ambiance, couleur d'ambiance, fond]
const KEYS: Array[Array] = [
	[0.0, 0.0, Color(1.0, 0.5, 0.4), 0.5, NIGHT_AMBIENT, NIGHT_BACKGROUND],
	[5.5, 0.0, Color(1.0, 0.5, 0.4), 0.5, NIGHT_AMBIENT, NIGHT_BACKGROUND],
	[6.5, 0.35, Color(1.0, 0.72, 0.5), 0.4, Color(0.55, 0.52, 0.66), DAWN_BACKGROUND],
	[8.0, 0.8, DAY_SUN, 0.5, DAY_AMBIENT, NIGHT_BACKGROUND],
	[17.0, 0.8, DAY_SUN, 0.5, DAY_AMBIENT, NIGHT_BACKGROUND],
	[19.25, 0.5, Color(1.0, 0.78, 0.62), 0.45, Color(0.62, 0.52, 0.6), DAWN_BACKGROUND],
	[20.5, 0.0, Color(1.0, 0.5, 0.4), 0.5, NIGHT_AMBIENT, NIGHT_BACKGROUND],
	[24.0, 0.0, Color(1.0, 0.5, 0.4), 0.5, NIGHT_AMBIENT, NIGHT_BACKGROUND],
]
const SUNRISE_HOUR := 6.0
const SUNSET_HOUR := 20.5
const MIN_ELEVATION_DEGREES := 8.0
const MAX_ELEVATION_DEGREES := 52.0
const MINUTES_PER_HOUR := 60.0
const HOURS_PER_DAY := 24.0


## La lumière à `minutes` après minuit.
static func sample(minutes: float) -> Dictionary:
	var hour := fposmod(minutes / MINUTES_PER_HOUR, HOURS_PER_DAY)
	var index := 0
	while index < KEYS.size() - 2 and hour >= float(KEYS[index + 1][0]):
		index += 1
	var low: Array = KEYS[index]
	var high: Array = KEYS[index + 1]
	var t := clampf((hour - low[0]) / (float(high[0]) - low[0]), 0.0, 1.0)
	var low_sun: Color = low[2]
	var low_ambient: Color = low[4]
	var low_background: Color = low[5]
	return {
		"sun_energy": lerpf(low[1], high[1], t),
		"sun_color": low_sun.lerp(high[2], t),
		"ambient_energy": lerpf(low[3], high[3], t),
		"ambient_color": low_ambient.lerp(high[4], t),
		"background": low_background.lerp(high[5], t),
		"sun_direction": sun_direction(hour),
	}


## Direction de la lumière du soleil (du soleil vers le sol), x vers l'est, z vers le sud.
static func sun_direction(hour: float) -> Vector3:
	var t := clampf((hour - SUNRISE_HOUR) / (SUNSET_HOUR - SUNRISE_HOUR), 0.0, 1.0)
	# Azimut compté depuis le sud : -90° à l'est le matin, +90° à l'ouest le soir.
	var azimuth := lerpf(-PI / 2.0, PI / 2.0, t)
	var elevation := deg_to_rad(lerpf(MIN_ELEVATION_DEGREES, MAX_ELEVATION_DEGREES, sin(t * PI)))
	var to_sun := Vector3(
		-sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation)
	)
	return -to_sun
