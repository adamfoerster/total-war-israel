extends Node
## Raiz do jogo: alterna entre a tela de setup e a batalha.

const Cfg = preload("res://scripts/config.gd")
const SetupScreen = preload("res://scripts/ui/setup_screen.gd")
const Battle = preload("res://scripts/battle.gd")

var setup: Control
var battle: Node3D
var last_army: Array = []
var last_hour := Cfg.HOUR_DEFAULT

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
		# posicionamento: a simulação não anda e a ordem fica presa ao setor de Israel
		battle.select_all()
		battle.rc_start = Vector2(600, 300)
		battle.rc_ground = Vector2(-450, -300)
		battle._issue_order(Vector2(600, 300))
		for k in 10:
			await get_tree().process_frame
		var in_sector := true
		for u in battle.player_units():
			if u.center.y < Cfg.SECTOR_HALF:
				in_sector = false
		print("posicionamento: tempo %.1f s, unidades no setor sul: %s" % [battle.sim.time, in_sector])
		ok = ok and battle.deploying and battle.sim.time == 0.0 and in_sector
		# depuração do acesso: camada de cores e declives ajustáveis
		battle._show_access(true)
		battle.set_slope_limits(20.0, 8.0)
		var dbg_ok: bool = battle.access_node != null and battle.access_node.visible \
			and battle.terrain.lim_foot == 20.0 and battle.terrain.lim_car == 8.0
		battle.set_slope_limits(Cfg.SLOPE_IMPASS, Cfg.SLOPE_CHARIOT)
		battle._show_access(false)
		print("depuração do acesso: ", dbg_ok)
		ok = ok and dbg_ok
		battle.start_battle()
		print("batalha iniciada: ", not battle.deploying)
		ok = ok and not battle.deploying
		battle.select_all()
		var d0: float = battle.player_units()[0].center.distance_to(Vector2(-450, -300))
		battle._issue_order(Vector2(600, 300))
		battle.cmd_run_toggle()
		battle.speed = 4.0
		for k in 300:
			await get_tree().process_frame
		var moved: bool = battle.player_units()[0].center.distance_to(Vector2(-450, -300)) < d0 - 10.0
		print("tempo de jogo: %.1f s  unidade 1 em %s" % [battle.sim.time, str(battle.player_units()[0].center.round())])
		ok = ok and battle.sim.time > 1.0 and moved
		battle.hud.surrender_dlg.popup_centered()
		battle.hud.surrender_dlg.confirmed.emit()
		for k in 5:
			await get_tree().process_frame
		print("rendição: vencedor %d, tela de resultado: %s" % [battle.sim.winner, battle.hud.result != null])
		ok = ok and battle.sim.winner == 1 and battle.sim.surrendered == 0 and battle.hud.result != null
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
