extends SceneTree
## Converte tiles Terrarium (AWS Terrain Tiles, zoom 13) em assets/jerusalem_height.res.
## Uso: godot --headless --path . -s tools/build_heightmap.gd

const N := 401
const CELL := 10.0
const LAT0 := 31.7765
const LON0 := 35.2365
const Z := 13
const TX0 := 4897
const TY0 := 3332
const SMOOTH_PASSES := 1      # antes eram 2
const DETAIL_AMP := 6.0       # metros de relevo fino acrescentado
const DETAIL_WAVE := 120.0    # comprimento de onda base do relevo fino, em metros

func _init() -> void:
	var mos := PackedFloat32Array()
	mos.resize(512 * 512)
	for ty in 2:
		for tx in 2:
			var p := ProjectSettings.globalize_path("res://tools/dem_raw/13_%d_%d.png" % [TX0 + tx, TY0 + ty])
			var img := Image.load_from_file(p)
			if img == null or img.get_width() != 256:
				push_error("tile ausente: " + p)
				quit(1)
				return
			img.convert(Image.FORMAT_RGB8)
			var d := img.get_data()
			for y in 256:
				for x in 256:
					var o := (y * 256 + x) * 3
					mos[(ty * 256 + y) * 512 + tx * 256 + x] = d[o] * 256.0 + d[o + 1] + d[o + 2] / 256.0 - 32768.0
	var out := PackedFloat32Array()
	out.resize(N * N)
	var mlat := 110900.0
	var mlon := 111320.0 * cos(deg_to_rad(LAT0))
	var scale := 256.0 * pow(2.0, Z)
	for j in N:
		for i in N:
			var lon := LON0 + (i - 200) * CELL / mlon
			var lat := LAT0 - (j - 200) * CELL / mlat
			var px := (lon + 180.0) / 360.0 * scale - TX0 * 256.0 - 0.5
			var lr := deg_to_rad(lat)
			var py := (1.0 - log(tan(lr) + 1.0 / cos(lr)) / PI) / 2.0 * scale - TY0 * 256.0 - 0.5
			px = clampf(px, 0.0, 510.99)
			py = clampf(py, 0.0, 510.99)
			var ix := int(px)
			var iy := int(py)
			var fx := px - ix
			var fy := py - iy
			var k := iy * 512 + ix
			out[j * N + i] = lerpf(lerpf(mos[k], mos[k + 1], fx), lerpf(mos[k + 512], mos[k + 513], fx), fy)
	# suavização leve (remove degraus de reamostragem e ruído de edificações)
	for pass_i in SMOOTH_PASSES:
		var src := out.duplicate()
		for j in range(1, N - 1):
			for i in range(1, N - 1):
				var k := j * N + i
				out[k] = (src[k] * 4.0 + (src[k - 1] + src[k + 1] + src[k - N] + src[k + N]) * 2.0
					+ src[k - N - 1] + src[k - N + 1] + src[k + N - 1] + src[k + N + 1]) / 16.0
	# relevo fino que os tiles de ~19 m não trazem: ruído fractal de poucos metros
	var fn := FastNoiseLite.new()
	fn.seed = 7
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 3
	fn.frequency = 1.0 / DETAIL_WAVE
	for j in N:
		for i in N:
			out[j * N + i] += fn.get_noise_2d(i * CELL, j * CELL) * DETAIL_AMP
	var img_out := Image.create_from_data(N, N, false, Image.FORMAT_RF, out.to_byte_array())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets"))
	var err := ResourceSaver.save(img_out, "res://assets/jerusalem_height.res")
	print("save err=", err)
	_report(out)
	quit(0)

func _report(h: PackedFloat32Array) -> void:
	var mn := 1e9
	var mx := -1e9
	for v in h:
		mn = minf(mn, v)
		mx = maxf(mx, v)
	print("altitude min=%.1f max=%.1f" % [mn, mx])
	var hist := [0, 0, 0, 0, 0, 0, 0, 0]
	var smax := 0.0
	var rows: Array = []
	for j in range(5, N - 1, 10):
		var line := ""
		var line2 := ""
		for i in range(5, N - 1, 10):
			var k := j * N + i
			var gx := (h[k + 1] - h[k - 1]) / 20.0
			var gz := (h[k + N] - h[k - N]) / 20.0
			var s := rad_to_deg(atan(sqrt(gx * gx + gz * gz)))
			line += "#" if s > 32.0 else ("+" if s > 20.0 else (":" if s > 12.0 else "."))
			line2 += "%d" % clampi(int((h[k] - mn) / (mx - mn) * 9.99), 0, 9)
		rows.append(line + "   " + line2)
	for j in range(1, N - 1):
		for i in range(1, N - 1):
			var k := j * N + i
			var gx := (h[k + 1] - h[k - 1]) / 20.0
			var gz := (h[k + N] - h[k - N]) / 20.0
			var s := rad_to_deg(atan(sqrt(gx * gx + gz * gz)))
			smax = maxf(smax, s)
			hist[mini(int(s / 5.0), 7)] += 1
	print("declive max=%.1f  hist(5 graus)=%s" % [smax, str(hist)])
	print("declive (. <12  : <20  + <32  # >32)      altitude 0-9   [norte em cima, 100 m por caractere]")
	for r in rows:
		print(r)
