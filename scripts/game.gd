extends Node
## Estado global, dados de heróis, fases e história de "Novaéria: O Beijo da Morte".

const HEROES := {
	"bron": {"nome": "Bron", "titulo": "O Guerreiro Sobrevivente", "hp": 160.0, "vel": 4.2, "cor": Color("b03a2e"),
		"desc": "Tanque / Quebra de Postura. Golpes pesados, Aparar e Fúria."},
	"solys": {"nome": "Solys Regis", "titulo": "A Sacerdotisa Inquisidora", "hp": 110.0, "vel": 5.0, "cor": Color("f4d35e"),
		"desc": "Suporte / Dano sagrado. Fogo de Ouro e Fogo Prateado, cura e purifica."},
	"ziggs": {"nome": "Ziggs Spark", "titulo": "O Engenheiro Goblin", "hp": 90.0, "vel": 5.6, "cor": Color("5fae4a"),
		"desc": "Controle de área. Torreta, minas e adrenalina; gerencia Pressão a Vácuo."},
}
const PARTY_ORDER := ["bron", "solys", "ziggs"]

# Setores do mapa único (ordem da história). Cada setor tem textos de abertura/encerramento e atmosfera.
const SETORES := {
	"estalagem": {"nome": "Estalagem do Cervo Prateado", "cap": "Cap. 8-10 — A Invasão da Estalagem",
		"intro": ["Bron entrega uma encomenda de armas na Estalagem do Cervo Prateado quando os caçadores de Lyla atacam.",
			"Um mago de olhar dourado e um ladino em fuga chegam ao mesmo tempo. Ninguém escolheu essa aliança — mas é lutar juntos ou morrer sozinho."],
		"outro": ["Os caçadores recuam. O trio sobrevive à primeira noite.", "A trilha leva à Floresta de Oakhaven."],
		"rocha": Color("4a3326"), "topo": Color("8a6238"), "fundo": Color("1d120d"), "ambiente": Color("8a6650"), "luz": Color("ff9a4a")},
	"floresta": {"nome": "Floresta de Oakhaven", "cap": "Cap. 12 — Pacto de Sangue",
		"intro": ["Na floresta, Bron, Solys e Ziggs discutem. Um mapa roubado pode revelar uma relíquia capaz de deter o ritual de Lyla.",
			"Mas o Culto do Sangue de Ferro já farejou o rastro."],
		"outro": [],
		"rocha": Color("2b3a2a"), "topo": Color("4f8a3a"), "fundo": Color("07140c"), "ambiente": Color("5a8a68"), "luz": Color("9affc0")},
	"kaldrak": {"nome": "Ruínas de Kal-Drak", "cap": "Cap. 14 — As Ruínas de Kal-Drak",
		"intro": ["Um templo em ruínas guarda a relíquia. O Capelão de Ferro queima sangue coagulado nos corredores — e a Besta de Transfusão guarda o altar."],
		"outro": ["A relíquia é deles. Agora resta a Cripta dos Sussurros."],
		"rocha": Color("55525f"), "topo": Color("8a8698"), "fundo": Color("0e0e16"), "ambiente": Color("7a7aa8"), "luz": Color("ff8a3a")},
	"marcha": {"nome": "Perímetro da Cripta dos Sussurros", "cap": "Cap. 16 — A Marcha para a Cripta",
		"intro": ["Bron lidera o avanço, Ziggs desarma armadilhas, Solys dissipa as barreiras. Os portões da Cripta estão à vista."],
		"outro": [],
		"rocha": Color("3e2d52"), "topo": Color("7a5a9a"), "fundo": Color("0c0614"), "ambiente": Color("6a5a90"), "luz": Color("b36aff")},
	"cripta": {"nome": "Salão do Ritual — Cripta dos Sussurros", "cap": "Cap. 17-18 — Lorde Valerius",
		"intro": ["Lorde Valerius, o Abominável de Sangue e Aço, bloqueia o caminho: hemomancia vampírica fundida a pistões e aço.",
			"Criado por Lyla para ser executor da sua vontade. Derrubá-lo é abrir a porta do trono."],
		"outro": ["O aço se cala. A porta do altar se abre."],
		"rocha": Color("52202c"), "topo": Color("9a3a4a"), "fundo": Color("1a0509"), "ambiente": Color("a05060"), "luz": Color("ff3b3b")},
	"altar": {"nome": "Altar de Lyla", "cap": "Cap. 19 — O Beijo Quebrado",
		"intro": ["Lyla, a Rainha da Ruína, surge como uma dama de vestido carmesim... até que os olhos acendem, as rosas murcham e as presas aparecem.",
			"“Vocês limparam o tabuleiro para mim.” Seu Beijo da Morte drena a vida de quem ela toca. Só a união do trio pode quebrá-lo."],
		"outro": [],
		"rocha": Color("33143c"), "topo": Color("8a3a8a"), "fundo": Color("12041a"), "ambiente": Color("a050a8"), "luz": Color("ff4ad8")},
	"confluencia": {"nome": "Confluência Submersa", "cap": "O coração dos caminhos esquecidos",
		"intro": ["Sob Novaéria, todas as rotas esquecidas se encontram numa gruta de águas negras e cristais frios. Daqui partem os caminhos para a floresta, os túneis e a marcha até a Cripta."],
		"outro": [],
		"rocha": Color("2c4658"), "topo": Color("5a8aa8"), "fundo": Color("050b12"), "ambiente": Color("5a8aa8"), "luz": Color("5ad0ff")},
	"subterraneo": {"nome": "Túneis de Aethelgard", "cap": "Rota esquecida sob Novaéria",
		"intro": ["Sob a Estalagem, antigos túneis de Aethelgard cortam o reino de ponta a ponta. Ziggs jura conhecer um atalho — e uma velha oficina goblin."],
		"outro": [],
		"rocha": Color("39434d"), "topo": Color("6a7d90"), "fundo": Color("06090d"), "ambiente": Color("5a7090"), "luz": Color("6ac8ff")},
}

const EPILOGO := ["Lyla cai e o altar desmorona. O Beijo da Morte foi quebrado.",
	"Mas a corrupção se espalhou pelas raízes do reino.",
	"Bron, Solys e Ziggs decidem permanecer juntos como os Protetores de Novaéria.",
	"— Fim do Livro 2 —"]

const PROLOGO := ["A SOMBRA DA RAINHA",
	"A Batalha dos Picos Nebulosos acabou. Vorn, Azrael e Kargoth caíram, e Novaéria celebra.",
	"Nas profundezas da Cripta de Oakhaven, Lyla sorri. Os generais eram peças — fundações de um edifício maior.",
	"“Prepare o Culto, Valerius. Diga a Bron que a comédia terminou. A Rainha reivindica o seu trono.”"]

var nivel := 0
var hp := {}           # hp atual de cada herói
var contam := {}       # Contaminação Sanguínea (0..100)
var vivos := {}
var mortes_total := 0
var flags := {}         # progresso do mapa: mapa, propulsor, reliquia, besta, valerius, itens...
var bonus_hp := 0.0     # Fragmentos de Coração
var respawn := "estalagem"
var explorado := PackedByteArray()

func hp_max(k: String) -> float:
	return HEROES[k]["hp"] + bonus_hp

func _ready() -> void:
	_registrar_inputs()
	novo_jogo()

func novo_jogo() -> void:
	nivel = 0
	mortes_total = 0
	flags = {}
	bonus_hp = 0.0
	respawn = "estalagem"
	explorado = PackedByteArray()
	for k in HEROES.keys():
		hp[k] = HEROES[k]["hp"]
		contam[k] = 0.0
		vivos[k] = true

func _registrar_inputs() -> void:
	var mapa := {
		"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "jump": [KEY_SPACE, KEY_W, KEY_UP], "mapa": [KEY_M, KEY_TAB],
		"atk": [KEY_J], "sk1": [KEY_K], "sk2": [KEY_L], "ult": [KEY_I, KEY_R],
		"prev": [KEY_Q], "next": [KEY_E], "h1": [KEY_1], "h2": [KEY_2], "h3": [KEY_3],
		"confirm": [KEY_ENTER, KEY_SPACE, KEY_J], "pause": [KEY_ESCAPE, KEY_P],
	}
	for acao in mapa.keys():
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
		for k in mapa[acao]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(acao, ev)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("atk", mb)
	# Gamepad básico
	var pad := {"jump": JOY_BUTTON_A, "atk": JOY_BUTTON_X, "sk1": JOY_BUTTON_B, "sk2": JOY_BUTTON_Y, "ult": JOY_BUTTON_RIGHT_STICK, "mapa": JOY_BUTTON_BACK,
		"prev": JOY_BUTTON_LEFT_SHOULDER, "next": JOY_BUTTON_RIGHT_SHOULDER, "confirm": JOY_BUTTON_A, "pause": JOY_BUTTON_START}
	for acao in pad.keys():
		var jb := InputEventJoypadButton.new()
		jb.button_index = pad[acao]
		InputMap.action_add_event(acao, jb)
	var eixos := {"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0], "up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0]}
	for acao in eixos.keys():
		var jm := InputEventJoypadMotion.new()
		jm.axis = eixos[acao][0]
		jm.axis_value = eixos[acao][1]
		InputMap.action_add_event(acao, jm)
