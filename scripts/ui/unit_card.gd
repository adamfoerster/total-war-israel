extends Control
## Card de unidade: única forma de selecionar tropas. Mostra soldados, moral,
## cansaço, força e munição.

signal clicked(unit, additive)

const Cfg = preload("res://scripts/config.gd")

var unit
var selected := false

func _init() -> void:
	custom_minimum_size = Vector2(58, 92)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(unit, ev.ctrl_pressed or ev.shift_pressed)
		accept_event()

func refresh(sel: bool) -> void:
	selected = sel
	var st := "sob controle"
	if unit.state == 1:
		st = "EM FUGA"
	elif unit.state == 2:
		st = "fora de combate"
	tooltip_text = "%s%s\n%s\nSoldados: %d/%d\nMoral: %d\nCansaço: %d\nForça: %d%%%s\n%s" % [
		unit.label, " — GENERAL" if unit.is_general else "", st, unit.men(), unit.men_init,
		int(unit.morale), int(unit.fatigue), unit.strength_pct(),
		("\nMunição: %d" % unit.ammo) if int(unit.t.ammo) > 0 else "",
		"Correndo" if unit.running else "Andando"]
	queue_redraw()

func _bar(y: float, frac: float, col: Color) -> void:
	draw_rect(Rect2(5, y, size.x - 10, 6), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(5, y, (size.x - 10) * clampf(frac, 0.0, 1.0), 6), col)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var gone: bool = unit.state != 0
	var bg := Color(0.17, 0.22, 0.36)
	if unit.state == 1:
		bg = Color(0.45, 0.45, 0.45)
	elif unit.state == 2:
		bg = Color(0.16, 0.16, 0.16)
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	var border := Color(1, 0.85, 0.2) if selected else Color(0.05, 0.05, 0.08)
	draw_rect(Rect2(Vector2.ZERO, size), border, false, 3.0 if selected else 1.0)
	var title: String = unit.t.short
	draw_string(font, Vector2(5, 17), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	if unit.is_general:
		draw_string(font, Vector2(30, 17), "GEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(1, 0.85, 0.2) if unit.general_alive else Color(0.6, 0.2, 0.2))
	elif unit.running and not gone:
		draw_string(font, Vector2(34, 17), ">>", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 1, 0.7))
	draw_string(font, Vector2(5, 33), "%d" % unit.men(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.95, 0.85))
	if unit.state == 1:
		draw_string(font, Vector2(5, 52), "FUGA", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1))
		return
	if unit.state == 2:
		draw_string(font, Vector2(5, 52), "---", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.6, 0.6))
		return
	_bar(40, float(unit.men()) / unit.men_init, Color(0.85, 0.85, 0.85))
	_bar(49, unit.morale / 100.0, Color(0.3, 0.8, 0.35))
	_bar(58, unit.fatigue / 100.0, Color(0.95, 0.55, 0.15))
	if int(unit.t.ammo) > 0:
		_bar(67, float(unit.ammo) / int(unit.t.ammo), Color(0.35, 0.65, 1.0))
	var sp: int = unit.strength_pct()
	var sc := Color(0.6, 1, 0.6) if sp >= 100 else (Color(1, 1, 0.6) if sp >= 80 else Color(1, 0.55, 0.45))
	draw_string(font, Vector2(5, 87), "F %d%%" % sp, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, sc)
