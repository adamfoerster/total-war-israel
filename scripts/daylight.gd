extends RefCounted
## Luz do dia: posição do sol, cor e intensidades para uma hora (solar) do dia.
## Coordenadas do mundo: x para leste, z para sul, y para cima.

const Cfg = preload("res://scripts/config.gd")

const LOW_SUN := Color(1.0, 0.62, 0.38)
const HIGH_SUN := Color(1.0, 0.96, 0.88)
const LOW_SKY := Color(0.86, 0.6, 0.46)
const HIGH_SKY := Color(0.62, 0.74, 0.88)

## Hora como "10:15".
static func clock(hour: float) -> String:
	var m := int(round(hour * 60.0))
	return "%d:%02d" % [m / 60, m % 60]

static func period(hour: float) -> String:
	if hour < 8.0:
		return "amanhecer"
	if hour < 11.5:
		return "manhã"
	if hour < 14.0:
		return "meio-dia"
	if hour < 17.0:
		return "tarde"
	return "entardecer"

## Devolve {to_sun (direção para o sol), alt (graus, já com o mínimo), sun_color,
## sun_energy, ambient_energy, sky}.
static func at(hour: float) -> Dictionary:
	var lat := deg_to_rad(Cfg.LATITUDE)
	var dec := deg_to_rad(Cfg.SUN_DECLINATION)
	var ha := deg_to_rad((hour - 12.0) * 15.0)
	var sin_alt := sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(ha)
	var alt := asin(clampf(sin_alt, -1.0, 1.0))
	var cos_az := (sin(dec) - sin(alt) * sin(lat)) / maxf(cos(alt) * cos(lat), 0.0001)
	var az := acos(clampf(cos_az, -1.0, 1.0))
	if ha > 0.0:
		az = TAU - az   # à tarde o sol está a oeste
	alt = maxf(alt, deg_to_rad(Cfg.SUN_MIN_ALT))
	var to_sun := Vector3(sin(az) * cos(alt), sin(alt), -cos(az) * cos(alt))
	var t := clampf((rad_to_deg(alt) - Cfg.SUN_MIN_ALT) / 40.0, 0.0, 1.0)
	return {
		"to_sun": to_sun,
		"alt": rad_to_deg(alt),
		"sun_color": LOW_SUN.lerp(HIGH_SUN, t),
		"sun_energy": lerpf(0.75, 1.2, t),
		"ambient_energy": lerpf(0.4, 0.55, t),
		"sky": LOW_SKY.lerp(HIGH_SKY, t),
	}
