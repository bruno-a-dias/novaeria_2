class_name Mapa
extends RefCounted
## Mapa único do jogo (estilo metroidvania): grade de tiles 1x1 (x → direita, y → cima).
## Células: 0 vazio · 1 sólido · 2 plataforma (atravessa por baixo) · 3 espinhos.
## Os setores seguem a ordem da história e se interligam por portas, portões, atalhos e poços.

const W := 340
const H := 152
const GRAV := 36.0

# Ordem de prioridade: o primeiro retângulo que contém a célula define o setor. [id, x0, y0, x1, y1(, chão)] (x1/y1 exclusivos).
# O 6º valor (opcional) é a altura do chão principal, usada para alinhar a arte de fundo.
# Topologia (hub): Estalagem → Floresta → Kal-Drak em cima; a Confluência Submersa fica no centro e liga o Porão,
# a Floresta (buraco no chão), os Túneis (poço) e a Marcha (corredor com o Portão de Ferro). Marcha → Cripta → Altar.
const SETOR_RECTS := [
	["altar", 310, 120, 340, 148],
	["cripta", 247, 116, 310, 148],
	["subterraneo", 10, 70, 40, 88, 76],
	["confluencia", 40, 20, 190, 90, 40],
	["subterraneo", 40, 6, 115, 20, 8],
	["kaldrak", 131, 90, 200, 140],
	["marcha", 190, 70, 247, 130],
	["floresta", 64, 88, 131, 122],
	["estalagem", 0, 88, 65, 122],
]

var g := PackedByteArray()
var gt := PackedByteArray()          # 1 = célula de portão fechado (sólida)
var salas: Array = []                # {id, setor, x0, y0, x1, y1, deco, inimigos}
var portoes := {}                    # id -> {x0,y0,x1,y1,fechado}
var bancos: Array = []               # {id, nome, x, y}
var itens: Array = []                # {id, x, y, tipo, nome, texto, flag, req}
var arenas: Array = []
var gatilhos: Array = []             # {id, x0,y0,x1,y1, acao}
var inicio := Vector2(7, 90)
var _ox := 0                         # deslocamento atual dos construtores (coordenadas locais → mundo)
var _oy := 0

func _init() -> void:
	g.resize(W * H)
	g.fill(1)
	gt.resize(W * H)
	gt.fill(0)
	_construir()

# ------------------------------------------------------------------ consulta
func em(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H

func tile(x: int, y: int) -> int:
	if not em(x, y):
		return 1
	return g[y * W + x]

func solido_t(x: int, y: int) -> bool:
	if not em(x, y):
		return true
	return g[y * W + x] == 1 or gt[y * W + x] == 1

func setor_de(x: float, y: float) -> String:
	for r in SETOR_RECTS:
		if x >= r[1] and x < r[3] and y >= r[2] and y < r[4]:
			return r[0]
	# fora dos retângulos (rocha maciça): setor do retângulo mais próximo
	var melhor := "estalagem"
	var md := 1.0e9
	for r in SETOR_RECTS:
		var dx := maxf(maxf(r[1] - x, x - r[3]), 0.0)
		var dy := maxf(maxf(r[2] - y, y - r[4]), 0.0)
		var d := dx * dx + dy * dy
		if d < md:
			md = d
			melhor = r[0]
	return melhor

func solido_em(p: Vector3) -> bool:
	return solido_t(floori(p.x), floori(p.y))

## Altura da superfície mais próxima abaixo de (x, y_inicio).
func chao_em(x: float, y_inicio: float) -> float:
	var cx := floori(x)
	var cy := mini(floori(y_inicio), H - 1)
	while cy >= 0:
		var t := tile(cx, cy)
		if t == 1 or t == 2 or gt[cy * W + cx] == 1:
			return float(cy + 1)
		cy -= 1
	return 0.0

func caixa_livre(cx: float, y: float, meia: float, alt: float) -> bool:
	var x0 := floori(cx - meia + 0.001)
	var x1 := floori(cx + meia - 0.001)
	var y0 := floori(y + 0.001)
	var y1 := floori(y + alt - 0.001)
	for xx in range(x0, x1 + 1):
		for yy in range(y0, y1 + 1):
			if solido_t(xx, yy):
				return false
	return true

func espinhos_em(cx: float, y: float, meia: float, alt: float) -> bool:
	var x0 := floori(cx - meia)
	var x1 := floori(cx + meia)
	var y0 := floori(y + 0.05)
	var y1 := floori(y + minf(alt, 1.0))
	for xx in range(x0, x1 + 1):
		for yy in range(y0, y1 + 1):
			if tile(xx, yy) == 3:
				return true
	return false

## Move uma caixa (pés em pos.y, centro em pos.x) por 'd' com colisão por eixo.
## Retorna {pos, chao, bateu_x, teto}.
func mover(pos: Vector3, d: Vector2, meia: float, alt: float, desce: bool = false, degrau: bool = true) -> Dictionary:
	var px := pos.x
	var py := pos.y
	var chao := false
	var bateu := false
	var teto := false
	# --- eixo X
	if d.x != 0.0:
		var nx := px + d.x
		if caixa_livre(nx, py, meia, alt):
			px = nx
		else:
			# degrau de 1 tile (suaviza terreno)
			if degrau and caixa_livre(nx, py + 1.01, meia, alt) and caixa_livre(px, py + 1.01, meia, alt) and _tem_apoio(px, py, meia):
				px = nx
				py = floorf(py + 0.01) + 1.0
			else:
				bateu = true
				if d.x > 0.0:
					px = floorf(nx + meia) - meia - 0.002
				else:
					px = ceilf(nx - meia) + meia + 0.002
	# --- eixo Y
	var ny := py + d.y
	if d.y > 0.0:
		if caixa_livre(px, ny, meia, alt):
			py = ny
		else:
			teto = true
			py = floorf(ny + alt) - alt - 0.002
			if py < pos.y - 0.001:
				py = pos.y
	else:
		var topo := -1.0
		var x0 := floori(px - meia + 0.001)
		var x1 := floori(px + meia - 0.001)
		var r_fim := floori(ny)
		for xx in range(x0, x1 + 1):
			var yy := floori(py + 0.05)
			while yy >= r_fim:
				var top := float(yy + 1)
				if top <= py + 0.05 and top >= ny - 0.0001:
					if solido_t(xx, yy) or (tile(xx, yy) == 2 and not desce):
						topo = maxf(topo, top)
						break
				yy -= 1
		if topo >= 0.0:
			py = topo
			chao = true
		else:
			py = ny
	return {"pos": Vector3(px, py, pos.z), "chao": chao, "bateu_x": bateu, "teto": teto}

func _tem_apoio(px: float, py: float, meia: float) -> bool:
	# só sobe degrau se estiver apoiado em algo
	var y := floori(py - 0.05)
	for xx in range(floori(px - meia + 0.001), floori(px + meia - 0.001) + 1):
		if tile(xx, y) == 1 or tile(xx, y) == 2 or gt[maxi(y, 0) * W + xx] == 1:
			return true
	return false

# ------------------------------------------------------------------ portões
func portao(id: String, x0: int, y0: int, x1: int, y1: int, fechado: bool = true) -> void:
	portoes[id] = {"x0": x0 + _ox, "y0": y0 + _oy, "x1": x1 + _ox, "y1": y1 + _oy, "fechado": false}
	definir_portao(id, fechado)

func definir_portao(id: String, fechado: bool) -> void:
	var p: Dictionary = portoes[id]
	p["fechado"] = fechado
	for xx in range(p["x0"], p["x1"] + 1):
		for yy in range(p["y0"], p["y1"] + 1):
			gt[yy * W + xx] = 1 if fechado else 0

# ------------------------------------------------------------------ construção
func _fill(x0: int, y0: int, x1: int, y1: int, v: int) -> void:
	for xx in range(x0 + _ox, x1 + _ox + 1):
		for yy in range(y0 + _oy, y1 + _oy + 1):
			if em(xx, yy):
				g[yy * W + xx] = v

func abrir(x0: int, y0: int, x1: int, y1: int) -> void:
	_fill(x0, y0, x1, y1, 0)

func solido(x0: int, y0: int, x1: int, y1: int) -> void:
	_fill(x0, y0, x1, y1, 1)

func plat(x: int, superficie: int, w: int) -> void:
	for i in range(w):
		if tile(x + i + _ox, superficie - 1 + _oy) == 0:
			g[(superficie - 1 + _oy) * W + x + i + _ox] = 2

func espinhos(x: int, y: int, w: int) -> void:
	for i in range(w):
		g[(y + _oy) * W + x + i + _ox] = 3

## Desloca um retângulo [x0,y0,x1,y1] local para o mundo.
func _r(r: Array) -> Array:
	return [r[0] + _ox, r[1] + _oy, r[2] + _ox, r[3] + _oy]

func _inim(lista: Array) -> Array:
	var res: Array = []
	for e in lista:
		var n: Array = e.duplicate()
		n[1] = int(n[1]) + _ox
		if n.size() > 2:
			n[2] = int(n[2]) + _oy
		res.append(n)
	return res

## Colina trapezoidal: sobe 1 tile a cada 'passo' tiles até h, platô e desce.
func monte(x0: int, x1: int, base: int, h: int, passo: int = 1) -> void:
	for xx in range(x0, x1 + 1):
		var a := mini(xx - x0, x1 - xx) / passo
		var alt := mini(a + 1, h)
		_fill(xx, base, xx, base + alt - 1, 1)

func sala(id: String, x0: int, y0: int, x1: int, y1: int, deco: String = "", inimigos: Array = []) -> void:
	abrir(x0, y0, x1, y1)
	salas.append({"id": id, "setor": setor_de((x0 + x1) * 0.5 + _ox, (y0 + y1) * 0.5 + _oy), "x0": x0 + _ox, "y0": y0 + _oy, "x1": x1 + _ox, "y1": y1 + _oy, "deco": deco, "inimigos": _inim(inimigos)})

func banco(id: String, nome: String, x: int, y: int) -> void:
	bancos.append({"id": id, "nome": nome, "x": x + _ox, "y": y + _oy})

func item(id: String, x: float, y: float, tipo: String, nome: String, texto: String, req: String = "") -> void:
	itens.append({"id": id, "x": x + _ox, "y": y + _oy, "tipo": tipo, "nome": nome, "texto": texto, "req": req})

func _escada(ys: Array, x_l: int, x_r: int, w: int, primeiro_r: bool) -> void:
	# ledges alternados esquerda/direita
	var r := primeiro_r
	for s in ys:
		plat(x_r if r else x_l, s, w)
		r = not r

func _construir() -> void:
	_ox = 0
	_oy = 70
	_estalagem()
	_porao()
	_floresta()
	_kaldrak()
	_marcha()
	_cripta()
	_altar()
	_ox = 3
	_oy = 2
	_tuneis()
	_ox = 0
	_oy = 0
	_confluencia()

# ---- Setor 1: Estalagem do Cervo Prateado (cap. 8-10)
func _estalagem() -> void:
	# Salão principal: térreo + mezanino. Escada de degraus (plataformas) sobe à esquerda, desce à direita.
	sala("e_salao", 4, 20, 38, 34, "taverna")
	plat(8, 23, 4)                                 # degrau 1
	plat(13, 26, 4)                                # degrau 2
	plat(18, 29, 13)                               # mezanino (sobre o balcão)
	plat(32, 26, 4)                                # degrau de descida
	plat(36, 23, 3)
	banco("estalagem", "Estalagem do Cervo Prateado", 6, 20)
	abrir(24, 18, 28, 19)                          # alçapão para o porão
	abrir(38, 20, 41, 26)                          # passagem para o pátio
	# Pátio dos caçadores: arena de ondas (Lyla)
	sala("e_patio", 41, 20, 62, 33, "taverna_patio")
	plat(45, 23, 4)
	plat(51, 26, 5)
	plat(57, 23, 4)
	abrir(62, 20, 65, 26)                          # saída leste → Floresta de Oakhaven
	portao("pateo_w", 39, 20, 39, 26, false)
	portao("pateo_e", 63, 20, 63, 26, false)
	arenas.append({"id": "pateo", "setor": "estalagem", "trig": _r([47, 20, 60, 33]), "fecha": ["pateo_w", "pateo_e"], "abre": [],
		"ondas": [["sanguessuga", "sanguessuga", "sanguessuga"], ["sanguessuga", "sanguessuga", "irma", "sanguessuga"]], "boss": "",
		"flag": "a_pateo", "spawn_x": [44 + _ox, 60 + _ox], "nome": "Os caçadores de Lyla"})

# ---- Setor 7a: Porão sob a Estalagem (início dos Túneis de Aethelgard)
func _porao() -> void:
	sala("porao", 12, 6, 34, 17, "tuneis", [["sanguessuga", 20], ["sanguessuga", 29]])
	plat(14, 9, 4)
	plat(19, 12, 4)
	plat(24, 15, 3)
	plat(27, 18, 2)
	item("c_porao", 31, 6, "coracao", "Fragmento de Coração", "A vitalidade de todo o grupo aumenta (+15 de vida máxima).")
	abrir(34, 6, 37, 11)                           # saída leste → corredor até a Confluência

# ---- Setor 7b: Túneis de Aethelgard (túnel principal e Toca do Goblin), no fundo do mundo
func _tuneis() -> void:
	sala("t1", 37, 6, 84, 12, "tuneis", [["sanguessuga", 48], ["sanguessuga", 56], ["carnical", 70], ["sanguessuga", 78]])
	monte(44, 46, 6, 2)
	monte(66, 70, 6, 2)
	plat(52, 9, 4)
	plat(72, 9, 4)
	banco("tunel", "Fogueira dos Túneis", 60, 6)
	sala("toca", 84, 6, 109, 15, "tuneis")
	plat(88, 9, 4)
	plat(94, 12, 4)
	plat(100, 9, 4)
	portao("toca_w", 85, 6, 85, 14, false)
	portao("toca_e", 109, 6, 109, 14, false)
	arenas.append({"id": "toca", "setor": "subterraneo", "trig": _r([90, 6, 106, 15]), "fecha": ["toca_w", "toca_e"], "abre": [],
		"ondas": [["irma", "irma"], ["succubus", "irma", "sanguessuga"]], "boss": "", "flag": "a_toca", "spawn_x": [88 + _ox, 106 + _ox], "nome": "A Oficina Goblin"})
	item("propulsor", 105, 6, "habilidade", "Propulsor de Ziggs",
		"Ziggs adapta a velha engenhoca a vapor: todos os heróis ganham um SEGUNDO PULO no ar.", "a_toca")

# ---- Setor 8: Confluência Submersa (hub central; liga Porão, Floresta, Túneis e Marcha)
func _confluencia() -> void:
	sala("h_conf", 44, 40, 148, 84, "confluencia", [["carnical", 66], ["sanguessuga", 84], ["succubus", 96, 58], ["irma", 120], ["carnical", 132], ["succubus", 76, 66]])
	banco("conf", "Fogueira da Confluência", 80, 40)
	# --- oeste: corredor vindo do Porão (e escada de ledges até o chão)
	abrir(35, 76, 46, 81)
	var l := false
	for sy in range(43, 77, 3):
		plat(45 if l else 49, sy, 3)
		l = not l
	# --- norte: buraco no chão da Clareira de Oakhaven (cai na Confluência) e ledges para voltar
	abrir(113, 85, 115, 89)
	l = true
	for sy in range(43, 89, 3):
		plat(110 if l else 114, sy, 3)
		l = not l
	# --- sul: poço até o túnel principal dos Túneis de Aethelgard
	abrir(54, 15, 58, 39)
	l = true
	for sy in range(11, 40, 3):
		plat(54 if l else 56, sy, 3)
		l = not l
	# --- leste: corredor até o Portão de Ferro da Marcha (a trava fica do outro lado) + ledges
	abrir(148, 76, 189, 81)
	l = true
	for sy in range(43, 77, 3):
		plat(141 if l else 145, sy, 3)
		l = not l
	portao("atalho", 189, 76, 189, 81, true)
	gatilhos.append({"id": "dica_atalho", "rect": [176, 76, 188, 82], "acao": "dica", "nao": "atalho",
		"texto": "Um Portão de Ferro sela o corredor. A trava parece estar do outro lado, na Marcha..."})
	# --- plataformas centrais e recompensa
	plat(62, 52, 8)
	plat(76, 60, 9)
	plat(92, 54, 8)
	plat(100, 64, 7)
	plat(124, 50, 9)
	plat(136, 58, 4)
	plat(130, 61, 5)
	item("c_conf", 131, 61, "coracao", "Fragmento de Coração", "A Confluência guarda um nicho acima das águas: +15 de vida máxima.")

# ---- Setor 2: Floresta de Oakhaven (cap. 12)
func _floresta() -> void:
	sala("f_entrada", 65, 20, 79, 31, "floresta", [["sanguessuga", 71], ["carnical", 76]])
	monte(68, 72, 20, 2)
	sala("f_cabana", 64, 34, 78, 43, "cabana")
	abrir(79, 34, 80, 40)
	sala("f_clareira", 80, 20, 126, 47, "floresta", [["carnical", 92], ["sanguessuga", 100], ["sanguessuga", 108], ["carnical", 114], ["succubus", 98, 28], ["succubus", 112, 32], ["sanguessuga", 120]])
	solido(79, 32, 80, 33)
	monte(86, 91, 20, 3)
	monte(104, 110, 20, 2)
	espinhos(98, 20, 2)
	plat(85, 23, 3)
	plat(81, 26, 3)
	plat(85, 29, 3)
	plat(81, 32, 3)
	plat(94, 24, 4)
	plat(101, 27, 4)
	plat(108, 30, 4)
	plat(115, 26, 4)
	plat(96, 33, 5)
	plat(118, 33, 5)
	item("mapa", 70, 34, "chave", "Mapa Roubado",
		"O mapa de um caçador do Culto revela um caminho pelas Ruínas de Kal-Drak, onde a relíquia contra Lyla repousa. A Barreira de Sangue cede.")
	banco("floresta", "Clareira de Oakhaven", 122, 20)
	abrir(127, 20, 131, 26)
	portao("barreira", 128, 20, 128, 26, true)
	gatilhos.append({"id": "dica_barreira", "rect": _r([119, 20, 127, 26]), "acao": "dica", "nao": "mapa",
		"texto": "Uma Barreira de Sangue Coagulado bloqueia a passagem. Talvez algum caçador carregue um mapa com outro caminho..."})

# ---- Setor 3: Ruínas de Kal-Drak (cap. 14)
func _kaldrak() -> void:
	sala("k_patio", 131, 20, 151, 33, "ruinas", [["capelao", 142], ["sanguessuga", 136], ["sanguessuga", 146], ["irma", 148]])
	plat(135, 23, 4)
	plat(141, 26, 4)
	plat(146, 23, 4)
	# poço de ascensão até a Nave
	sala("k_poco", 152, 20, 160, 59, "ruinas", [["succubus", 156, 36], ["succubus", 155, 46]])
	abrir(151, 20, 152, 33)
	var ys := [23, 26, 29, 32, 35, 38, 41]
	var r := true
	for s in ys:
		plat(157 if r else 152, s, 3)
		r = not r
	plat(157, 44, 3)
	sala("k_nave", 161, 47, 185, 60, "ruinas", [["capelao", 170], ["capelao", 178], ["irma", 174], ["succubus", 166, 54]])
	plat(166, 50, 4)
	plat(173, 53, 5)
	plat(179, 50, 4)
	plat(163, 50, 3)
	plat(167, 53, 3)
	plat(163, 56, 3)
	item("c_nave", 164, 56, "coracao", "Fragmento de Coração", "O templo guarda mais do que dor: +15 de vida máxima.")
	banco("kaldrak", "Fogueira de Kal-Drak", 163, 47)
	sala("k_altar", 186, 47, 199, 62, "altar_besta")
	portao("besta_w", 185, 47, 185, 60, false)
	arenas.append({"id": "besta", "setor": "kaldrak", "trig": _r([187, 47, 199, 62]), "fecha": ["besta_w"], "abre": ["besta_chao"],
		"ondas": [["capelao", "sanguessuga", "sanguessuga"], ["irma", "succubus", "capelao"]], "boss": "besta",
		"flag": "besta", "spawn_x": [189 + _ox, 198 + _ox], "nome": "A Besta de Transfusão"})
	# poço de descida para a Marcha (fecha com o piso do altar até a Besta cair)
	abrir(193, 6, 199, 46)
	portao("besta_chao", 193, 46, 199, 46, true)
	item("reliquia", 190, 47, "chave", "Relíquia de Kal-Drak",
		"A Relíquia pulsa em prata. Contra a Rainha, é a única chave dos Portões da Cripta dos Sussurros.", "besta")

# ---- Setor 4: Marcha para a Cripta (cap. 16)
func _marcha() -> void:
	sala("m_base", 190, 6, 205, 19, "marcha", [["carnical", 202], ["sanguessuga", 200]])
	var s := 9
	var r := false
	while s <= 45:
		plat(198 if r else 193, s, 2)
		r = not r
		s += 3
	banco("marcha", "Fogueira da Marcha", 191, 6)
	gatilhos.append({"id": "alavanca_atalho", "rect": _r([190, 6, 193, 9]), "acao": "abrir_atalho"})
	sala("m_armadilhas", 205, 6, 232, 17, "marcha", [["carnical", 214], ["capelao", 222], ["irma", 228], ["sanguessuga", 210]])
	espinhos(209, 6, 2)
	espinhos(217, 6, 2)
	espinhos(225, 6, 2)
	plat(210, 10, 4)
	plat(218, 10, 4)
	plat(226, 10, 4)
	sala("m_portoes", 232, 6, 246, 22, "marcha_portoes", [["irma", 240], ["irma", 243]])
	portao("cripta", 233, 6, 233, 14, true)
	gatilhos.append({"id": "portao_cripta", "rect": _r([229, 6, 232, 14]), "acao": "abrir_cripta"})
	banco("poco", "Fogueira dos Portões", 236, 6)
	gatilhos.append({"id": "dica_poco", "rect": _r([238, 6, 246, 10]), "acao": "dica", "nao": "propulsor",
		"texto": "O Poço é alto demais para um único salto. Ziggs murmura sobre uma velha oficina goblin nos Túneis de Aethelgard..."})
	# Poço da Cripta: exige pulo duplo (saltos de 5 tiles)
	sala("m_poco", 238, 6, 246, 58, "poco", [["succubus", 242, 22], ["succubus", 240, 34], ["succubus", 243, 44]])
	var ys := [11, 16, 21, 26, 31, 36, 41, 46]
	var l := true
	for sy in ys:
		plat(238 if l else 244, sy, 3)
		l = not l
	abrir(232, 26, 237, 31)
	item("c_poco", 234, 26, "coracao", "Fragmento de Coração", "Um nicho escondido no Poço. +15 de vida máxima.")

# ---- Setor 5: Cripta dos Sussurros — Salão do Ritual (cap. 17-18)
func _cripta() -> void:
	sala("c_antecamara", 247, 48, 262, 60, "cripta", [["capelao", 255], ["carnical", 258], ["irma", 252]])
	banco("cripta", "Fogueira da Antecâmara", 249, 48)
	sala("c_salao", 263, 48, 291, 66, "salao_ritual")
	plat(268, 52, 4)
	plat(278, 52, 5)
	plat(285, 55, 4)
	plat(272, 56, 4)
	portao("valerius_w", 262, 48, 262, 60, false)
	portao("valerius_e", 292, 48, 292, 56, true)
	arenas.append({"id": "valerius", "setor": "cripta", "trig": _r([265, 48, 290, 66]), "fecha": ["valerius_w"], "abre": ["valerius_e"],
		"ondas": [], "boss": "valerius", "flag": "valerius", "spawn_x": [282 + _ox, 289 + _ox], "nome": "Lorde Valerius"})
	abrir(292, 48, 310, 66)
	salas.append({"id": "c_escadaria", "setor": "cripta", "x0": 292 + _ox, "y0": 48 + _oy, "x1": 310 + _ox, "y1": 66 + _oy, "deco": "escadaria",
		"inimigos": _inim([["succubus", 300, 56], ["succubus", 304, 60]])})
	for xx in range(293, 311):
		var h := mini(48 + (xx - 293) / 2, 56)
		_fill(xx, 48, xx, h - 1, 1)
	banco("altar", "Fogueira da Escadaria", 309, 56)

# ---- Setor 6: Altar de Lyla (cap. 19-20)
func _altar() -> void:
	abrir(311, 56, 336, 74)
	salas.append({"id": "a_altar", "setor": "altar", "x0": 311 + _ox, "y0": 56 + _oy, "x1": 336 + _ox, "y1": 74 + _oy, "deco": "altar", "inimigos": []})
	plat(317, 60, 5)
	plat(326, 60, 5)
	plat(321, 64, 5)
	portao("altar_w", 310, 56, 310, 66, false)
	arenas.append({"id": "lyla", "setor": "altar", "trig": _r([315, 56, 335, 74]), "fecha": ["altar_w"], "abre": [],
		"ondas": [], "boss": "lyla", "flag": "lyla", "spawn_x": [328 + _ox, 333 + _ox], "nome": "Lyla, a Rainha da Ruína"})
