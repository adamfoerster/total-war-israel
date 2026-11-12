extends RefCounted
## Estado de uma unidade (card). Os soldados ficam nos arrays globais do BattleSim,
## no intervalo [start, start + n).

var id := 0
var side := 0
var type := 0
var t: Dictionary
var label := ""
var is_general := false
var general_alive := true

var start := 0
var cap := 0          # modelos iniciais
var n := 0            # modelos vivos
var mpm := 1          # homens por modelo
var men_init := 0

var center := Vector2.ZERO
var facing := Vector2(0, -1)
var want_facing := Vector2.ZERO
var dest_facing := Vector2.ZERO
var files := 1
var path := PackedVector2Array()
var path_i := 0
var target = null
var repath_t := 0.0
var running := false
var fire_at_will := true

var state := 0        # 0 sob controle, 1 em fuga, 2 fora de combate
var morale := 70.0
var morale_base := 70.0
var fatigue := 0.0
var ammo := 0
var reload_t := 0.0
var height_mod := 1.0
var str_mult := 1.0
var contacts := 0
var flank_t := 0.0
var charge_t := 0.0
var lost_acc := 0
var kills := 0

var vel := Vector2.ZERO
var dense := false
var qr := 1
var brad := 10.0
var active := false
var settling := true
var dirty := true
var formed := false    # posições implícitas (formação rígida, sem custo por soldado)
var in_grid := false   # soldados registrados na grade espacial
var safe := true       # sem declives proibidos por perto
var wake := PackedInt32Array()
var all_awake := false
var rows0 := 1                      # linhas da formação completa
var depth := PackedInt32Array()     # homens em cada fileira
var ragged := false                 # fileiras desiguais, precisa realinhar
var rigid := false
var flee_dir := Vector2.ZERO
var rout_t := 0.0
var rout_path := PackedVector2Array()   # rota de fuga até a borda do mapa
var rout_pi := 0
var rout_repath := 0.0
var rout_try := 0
var rout_blocked := false
var rout_stamp := 0

func men() -> int:
	return n * mpm

func rows() -> int:
	return rows0

func strength_pct() -> int:
	return int(round(str_mult * 100.0))
