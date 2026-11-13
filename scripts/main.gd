extends Node
## Raiz do jogo: alterna entre a tela de setup e a batalha.

const SetupScreen = preload("res://scripts/ui/setup_screen.gd")
const Battle = preload("res://scripts/battle.gd")

var setup: Control
var battle: Node3D
var last_army: Array = []
var last_hour := 10.0

func _ready() -> void:
	if "--simtest" in OS.get_cmdline_user_args():
		var t = load("res://scripts/sim_test.gd").new()
		get_tree().quit(1 if t.run() > 0 else 0)
		return
	_show_setup()
	if "--uitest" in OS.get_cmdline_user_args():
		_ui_test()

## Teste de fumaça da interface (godot --headless --path . -- --uitest): percorre
## setup -> batalha -> ordens -> resultado -> setup e falha se algo quebrar.
func _ui_test() -> void:
	await get_tree().process_frame
	setup._set_general(setup.rows[2])
	setup._go()
	for k in 10:
		await get_tree().process_frame
	var ok: bool = battle != null and battle.ready_ok
	if ok:
		var gens := 0
		for u in battle.player_units():
			gens += 1 if u.is_general else 0
		print("generais do jogador: ", gens, "  general no card 3: ", battle.player_units()[2].is_general)
		ok = gens == 1 and battle.player_units()[2].is_general
		battle.select_all()
		battle.rc_start = Vector2(600, 300)
		battle.rc_ground = Vector2(-450, -300)
		battle._issue_order(Vector2(600, 300))
		battle.cmd_run_toggle()
		battle.speed = 4.0
		for k in 300:
			await get_tree().process_frame
		var moved: bool = battle.player_units()[0].center.distance_to(Vector2(-450, -300)) < 400.0
		print("tempo de jogo: %.1f s  unidade 1 em %s" % [battle.sim.time, str(battle.player_units()[0].center.round())])
		ok = ok and battle.sim.time > 1.0 and moved
		battle.sim.winner = 0
		for k in 5:
			await get_tree().process_frame
		print("tela de resultado: ", battle.hud.result != null)
		ok = ok and battle.hud.result != null
		battle.leave()
		for k in 5:
			await get_tree().process_frame
		print("voltou ao setup: ", setup != null)
		ok = ok and setup != null
	print("UITEST ", "OK" if ok else "FALHOU")
	get_tree().quit(0 if ok else 1)

func _show_setup() -> void:
	if battle != null:
		battle.queue_free()
		battle = null
	setup = SetupScreen.new()
	setup.initial_army = last_army
	setup.initial_hour = last_hour
	setup.start_battle.connect(_start)
	add_child(setup)

func _start(army: Array, hour: float) -> void:
	last_army = army
	last_hour = hour
	setup.queue_free()
	setup = null
	battle = Battle.new()
	battle.army = army
	battle.hour = hour
	battle.finished.connect(_show_setup)
	add_child(battle)
