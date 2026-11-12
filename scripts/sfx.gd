extends Node
## Efeitos sonoros, reaproveitados do jogo de tabuleiro Promised Land.
## Cada tela cria a sua instância: `sfx = Sfx.new(); add_child(sfx)`.

const STREAMS := {
	"click": preload("res://assets/sounds/select2.mp3"),
	"menu": preload("res://assets/sounds/menu-select.mp3"),
	"march": preload("res://assets/sounds/march.mp3"),
	"sword": preload("res://assets/sounds/sword.mp3"),
	"win": preload("res://assets/sounds/win.mp3"),
	"lose": preload("res://assets/sounds/lose.mp3"),
}

var _players := {}

func _ready() -> void:
	for k: String in STREAMS:
		var p := AudioStreamPlayer.new()
		p.stream = STREAMS[k]
		add_child(p)
		_players[k] = p

func play(sound: String, vol_db := 0.0) -> void:
	var p: AudioStreamPlayer = _players.get(sound)
	if p == null:
		return
	p.volume_db = vol_db
	p.play()

func playing(sound: String) -> bool:
	var p: AudioStreamPlayer = _players.get(sound)
	return p != null and p.playing
