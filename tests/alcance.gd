extends SceneTree
## Valida o mapa: simula a física real do herói (pulo, pulo duplo, degraus) a partir da fogueira inicial
## e verifica quais pontos-chave são alcançáveis em cada etapa da progressão. Uso:
##   godot --headless --path . -s tests/alcance.gd

const GRAV := 36.0
const JV := 16.5
const VEL := 4.2           # herói mais lento (Bron)
const MEIA := 0.45
const ALT := 2.2
var mapa: Mapa

func _init() -> void:
	mapa = Mapa.new()
	var ok := true
	# etapa 1: início, sem Mapa Roubado e sem Propulsor
	var f1 := {}
	var r1 := alcance(f1, false)
	ok = _checa("Etapa 1 (início)", r1, [
		["fogueira estalagem", 6, 90, true], ["pátio", 50, 90, true], ["porão (chão)", 20, 76, true], ["coração do porão", 31, 76, true],
		["Confluência (chão)", 60, 40, true], ["fogueira Confluência", 80, 40, true], ["coração da Confluência", 131, 61, true],
		["corredor leste (portão)", 175, 76, true],
		["fogueira túnel", 63, 8, true], ["Toca (entrada)", 90, 8, true], ["Propulsor", 108, 8, true],
		["clareira (chão)", 100, 90, true], ["Cabana (Mapa Roubado)", 70, 104, true], ["fogueira floresta", 122, 90, true],
		["Kal-Drak pátio (barreira)", 135, 90, false], ["Marcha (base)", 195, 76, false],
	]) and ok
	# etapa 1b: lever do Portão de Ferro (atalho) aberto → Marcha base acessível a partir da Confluência
	var f1b := {"atalho": true}
	var r1b := alcance(f1b, false)
	ok = _checa("Etapa 1b (atalho aberto)", r1b, [["Marcha (base)", 195, 76, true], ["fogueira Marcha", 191, 76, true], ["Armadilhas", 215, 76, true], ["Portões (cripta fechada)", 236, 76, false]]) and ok
	# etapa 2: com o mapa (barreira aberta)
	var f2 := {"mapa": true, "a_pateo": true, "a_toca": true}
	var r2 := alcance(f2, false)
	ok = _checa("Etapa 2 (com Mapa, sem Propulsor)", r2, [
		["Kal-Drak pátio", 135, 90, true], ["Nave (fogueira)", 163, 117, true], ["coração da Nave", 164, 126, true], ["altar da Besta", 190, 117, true],
		["Marcha (base)", 195, 76, false],
	]) and ok
	# etapa 3: Besta derrotada (chão aberto), Relíquia
	var f3 := {"mapa": true, "a_pateo": true, "a_toca": true, "besta": true, "reliquia": true}
	var r3 := alcance(f3, false)
	ok = _checa("Etapa 3 (Besta derrotada, sem Propulsor)", r3, [
		["Marcha base (fogueira)", 191, 76, true], ["Armadilhas", 215, 76, true], ["Portões (cripta fechada)", 236, 76, false],
	]) and ok
	var f4 := {"mapa": true, "a_pateo": true, "a_toca": true, "besta": true, "reliquia": true, "cripta_aberta": true}
	var r4 := alcance(f4, false)
	ok = _checa("Etapa 4 (Portões abertos, SEM pulo duplo)", r4, [
		["Portões (fogueira)", 236, 76, true], ["base do Poço", 241, 76, true], ["topo do Poço (Cripta)", 249, 118, false], ["nicho do Poço", 234, 96, false],
	]) and ok
	var r5 := alcance(f4, true)
	ok = _checa("Etapa 5 (Portões abertos, COM pulo duplo)", r5, [
		["topo do Poço (Cripta)", 249, 118, true], ["nicho do Poço (coração)", 234, 96, true], ["antecâmara", 255, 118, true], ["Salão do Ritual", 275, 118, true],
		["escadaria", 300, 124, false],
	]) and ok
	var f6 := f4.duplicate()
	f6["valerius"] = true
	var r6 := alcance(f6, true)
	ok = _checa("Etapa 6 (Valerius derrotado)", r6, [
		["fogueira da escadaria", 309, 126, true], ["Altar de Lyla", 320, 126, true],
	]) and ok
	# voltas: Marcha → Kal-Drak (poço da Besta), Porão → Estalagem, Cabana → clareira, Toca → superfície, Confluência → todos os acessos
	var rv := alcance(f3, false, Vector2i(195, 76))
	ok = _checa("Volta: da Marcha para Kal-Drak", rv, [["altar da Besta", 190, 117, true], ["fogueira Kal-Drak", 163, 117, true], ["pátio Kal-Drak", 135, 90, true]]) and ok
	var rp := alcance(f2, false, Vector2i(20, 76))
	ok = _checa("Volta: do Porão para a Estalagem", rp, [["fogueira estalagem", 6, 90, true], ["pátio", 50, 90, true], ["Confluência", 80, 40, true]]) and ok
	var rc := alcance(f2, false, Vector2i(70, 104))
	ok = _checa("Volta: da Cabana para a clareira", rc, [["clareira", 100, 90, true], ["Kal-Drak", 135, 90, true]]) and ok
	var rt := alcance(f2, false, Vector2i(108, 8))
	ok = _checa("Volta: da Toca (Propulsor) para a superfície", rt, [["fogueira estalagem", 6, 90, true], ["clareira", 100, 90, true], ["Confluência", 80, 40, true]]) and ok
	var rh := alcance(f2, false, Vector2i(80, 40))
	ok = _checa("Da Confluência: todos os acessos", rh, [["Estalagem", 6, 90, true], ["clareira", 100, 90, true], ["Toca", 90, 8, true], ["corredor leste", 175, 76, true], ["Porão", 20, 76, true]]) and ok
	print("ALCANCE OK" if ok else "ALCANCE COM FALHAS")
	quit()

func _checa(titulo: String, r: Dictionary, alvos: Array) -> bool:
	var ok := true
	print("== ", titulo, "  (nós alcançados: ", r.size(), ")")
	for a in alvos:
		var vis := _visitado(r, a[1], a[2])
		var bom: bool = vis == a[3]
		if not bom:
			ok = false
		print("  %s %-34s (%d,%d) alcançável=%s esperado=%s" % ["OK " if bom else "ERR", a[0], a[1], a[2], vis, a[3]])
	return ok

func _visitado(r: Dictionary, x: int, y: int) -> bool:
	for dx in [0, -1, 1]:
		for dy in [0, -1, 1]:
			if r.has(Vector2i(x + dx, y + dy)):
				return true
	return false

func _portoes(f: Dictionary) -> void:
	mapa.definir_portao("barreira", not f.get("mapa", false))
	mapa.definir_portao("cripta", not f.get("cripta_aberta", false))
	mapa.definir_portao("atalho", not f.get("atalho", false))
	mapa.definir_portao("besta_chao", not f.get("besta", false))
	mapa.definir_portao("valerius_e", not f.get("valerius", false))

func alcance(f: Dictionary, duplo: bool, ini: Vector2i = Vector2i(7, 90)) -> Dictionary:
	_portoes(f)
	var vis := {}
	var fila: Array = [ini]
	vis[ini] = true
	while not fila.is_empty():
		var n: Vector2i = fila.pop_back()
		for dirx in [-1, 0, 1]:
			var variantes: Array = [[-1.0, -1.0]]                     # só andar
			if dirx == 0:
				variantes = []
			variantes.append([0.0, -1.0])                              # pulo simples
			if duplo:
				for t2 in [0.18, 0.32, 0.5, 0.7]:
					variantes.append([0.0, t2])
			for v in variantes:
				for p in _sim(n, dirx, v[0] >= 0.0 or v[1] > -1.0 or (v[0] == 0.0), v[1], v[0] == -1.0):
					if not vis.has(p):
						vis[p] = true
						fila.append(p)
	return vis

# Simula um movimento; retorna as células de pouso.
func _sim(n: Vector2i, dirx: int, pular: bool, t_duplo: float, so_andar: bool) -> Array:
	var res: Array = []
	var pos := Vector3(n.x + 0.5, float(n.y), 0.5)
	var vx := dirx * VEL
	var vy := 0.0
	var no_chao := true
	var extra := 1 if t_duplo > -1.0 or true else 0
	var pulos_extra := 1
	var dt := 1.0 / 60.0
	var t := 0.0
	var ja_pulou := false
	if pular and not so_andar:
		vy = JV
		no_chao = false
		ja_pulou = true
	var duplo_feito := false
	var prev_chao := true
	while t < 2.6:
		t += dt
		vy = maxf(vy - GRAV * dt, -26.0)
		if not no_chao and t_duplo > 0.0 and not duplo_feito and t >= t_duplo:
			vy = JV * 0.92
			duplo_feito = true
		var r: Dictionary = mapa.mover(pos, Vector2(vx, vy) * dt, MEIA, ALT, false)
		pos = r["pos"]
		if r["bateu_x"]:
			vx = 0.0
		if r["teto"] and vy > 0.0:
			vy = 0.0
		if r["chao"] and vy <= 0.0:
			vy = 0.0
			no_chao = true
			if not prev_chao or so_andar:
				res.append(Vector2i(floori(pos.x), roundi(pos.y)))
			if prev_chao and not so_andar:
				pass
			if not prev_chao and pular:
				break
		else:
			no_chao = false
		prev_chao = no_chao
		if so_andar and no_chao and t > 1.8:
			break
	if no_chao:
		res.append(Vector2i(floori(pos.x), roundi(pos.y)))
	return res
