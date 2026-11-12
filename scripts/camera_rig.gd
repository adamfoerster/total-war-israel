extends Node3D
## Câmera de estratégia: WASD/setas movem, Q/E giram, roda do mouse dá zoom.
## O alvo pode percorrer toda a área visível (maior que a área controlável).

const Cfg = preload("res://scripts/config.gd")

var terrain
var cam := Camera3D.new()
var target := Vector2(-450, -250)
var yaw := 0.0
var dist := 900.0

func _ready() -> void:
	cam.far = 12000.0
	cam.near = 1.0
	cam.fov = 50.0
	add_child(cam)
	cam.current = true
	_apply()

func zoom(f: float) -> void:
	dist = clampf(dist * f, 40.0, 3200.0)

func _process(delta: float) -> void:
	var mv := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		mv.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		mv.y -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		mv.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		mv.x -= 1.0
	if not Input.is_key_pressed(KEY_CTRL):
		if Input.is_key_pressed(KEY_Q):
			yaw += 1.2 * delta
		if Input.is_key_pressed(KEY_E):
			yaw -= 1.2 * delta
		if mv != Vector2.ZERO:
			var fwd := Vector2(-sin(yaw), -cos(yaw))
			var right := Vector2(cos(yaw), -sin(yaw))
			target += (fwd * mv.y + right * mv.x) * dist * 0.9 * delta
	target.x = clampf(target.x, -Cfg.HALF_MAP, Cfg.HALF_MAP)
	target.y = clampf(target.y, -Cfg.HALF_MAP, Cfg.HALF_MAP)
	_apply()

func _apply() -> void:
	var pitch := deg_to_rad(lerpf(28.0, 62.0, clampf((dist - 40.0) / 2000.0, 0.0, 1.0)))
	var ty: float = terrain.height(target.x, target.y)
	var t3 := Vector3(target.x, ty, target.y)
	var p := t3 + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	var ground: float = terrain.height(p.x, p.z) + 6.0
	if p.y < ground:
		p.y = ground
	cam.look_at_from_position(p, t3, Vector3.UP)

## Ponto do terreno sob a posição de tela dada, ou null.
func pick(screen: Vector2):
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	var t := 0.0
	var prev := 0.0
	while t < 9000.0:
		var p := o + d * t
		if p.y <= terrain.height(p.x, p.z):
			var a := prev
			var b := t
			for k in 10:
				var m := (a + b) * 0.5
				var pm := o + d * m
				if pm.y <= terrain.height(pm.x, pm.z):
					b = m
				else:
					a = m
			var r := o + d * b
			if absf(r.x) > Cfg.HALF_MAP or absf(r.z) > Cfg.HALF_MAP:
				return null
			return Vector2(r.x, r.z)
		prev = t
		t += maxf(4.0, t * 0.02)
	return null
