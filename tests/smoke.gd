extends Node
## Teste de fumaça do mundo único: percorre os setores teleportando o herói, aciona arenas e chefes com entradas aleatórias.
var mundo: World
var frame := 0
var passo := 0
var acoes := ["atk", "sk1", "sk2", "ult", "left", "right", "jump", "down"]
# pontos de teste (x, y) por setor, e flags que liberam as arenas
const PONTOS := [
	[8.0, 90.0], [50.0, 90.0], [20.0, 76.0], [80.0, 40.0], [63.0, 8.0], [95.0, 8.0], [70.0, 90.0], [100.0, 90.0],
	[140.0, 90.0], [165.0, 117.0], [190.0, 117.0], [195.0, 76.0], [215.0, 76.0], [240.0, 76.0],
	[255.0, 118.0], [275.0, 118.0], [300.0, 124.0], [325.0, 126.0],
]

func _ready() -> void:
	Game.novo_jogo()
	mundo = World.new()
	add_child(mundo)

var feito := false
func _process(_dt: float) -> void:
	if feito:
		return
	frame += 1
	for a in acoes:
		if randf() < 0.05:
			Input.action_press(a)
		elif randf() < 0.1:
			Input.action_release(a)
	if frame % 90 == 0:
		var k = ["h1", "h2", "h3"][randi() % 3]
		Input.action_press(k)
		Input.action_release(k)
	if frame % 240 == 0:
		for e in get_tree().get_nodes_in_group("enemies"):
			e.receber_dano(150.0, Vector3.ZERO, 0.0, 0.5)
		for k in Game.HEROES.keys():
			Game.vivos[k] = true
			Game.hp[k] = Game.hp_max(k)
	if frame % 300 == 0:
		if passo < PONTOS.size():
			var p = PONTOS[passo]
			mundo.teleportar(p[0], p[1])
			print("ponto %d -> (%.0f,%.0f) setor=%s inimigos=%d" % [passo, p[0], p[1], mundo.setor_atual, get_tree().get_nodes_in_group("enemies").size()])
			passo += 1
		else:
			feito = true
			print("flags:", Game.flags.keys())
			print("SMOKE OK")
			get_tree().quit()
