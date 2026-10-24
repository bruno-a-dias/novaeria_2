class_name World
extends Node3D
## Mundo único estilo metroidvania: setores interligados, portões, atalhos, bancos de descanso,
## chefes em arenas, itens de progressão, câmera lateral ortográfica (2.5D) e HUD com minimapa.

signal terminou(vitoria: bool)
signal historia_pedida(linhas: Array, titulo: String)

const CAM_TAM := 13.0
const CAM_Z := 30.0

var mapa: Mapa
var cenario: Cenario
var camera: Camera3D
var env: Environment
var herois := {}
var ativo_k := ""
var buff_t := 0.0
var troca_cd := 0.0
var t_total := 0.0
var setor_atual := ""
var setor_popup_t := -99.0
var salas_estado := {}            # id -> {estado, inim}
var arena: Dictionary = {}        # arena ativa
var arena_est := {}
var chefe_ref: Enemy = null
var itens_nos := {}
var fim_t := -1.0
var mapa_aberto := false
var _explor_t := 0.0
var _far_t := 0.0
var _img: Image
var _tex: ImageTexture
var _hint_t := {}
var _derrotado := false

# HUD
var hud: CanvasLayer
var linhas := {}
var l_area: Label
var l_sub: Label
var l_banner: Label
var l_prompt: Label
var l_status: Label
var l_obj: Label
var barra_chefe: ProgressBar
var l_chefe: Label
var l_ajuda: Label
var mini: MiniMapa
var grande: MiniMapa
var painel_mapa: Control
var flash: ColorRect
var particulas: GPUParticles3D
var _banner_t := 0.0
var _area_t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("mundo")
	mapa = Mapa.new()
	_construir_mundo()
	_criar_herois()
	_construir_hud()
	_iniciar_mapa_imagem()
	_aplicar_portoes(false)
	var p0 := _pos_banco(Game.respawn)
	_ambiente(mapa.setor_de(p0.x, p0.y + 1.0), true)
	_atualizar_camera(1.0, true)
	if OS.has_feature("web"):
		_registrar_js()

var _js_cbs: Array = []

## Ganchos de depuração no navegador: nvTeleport(x, y) e nvFlag("mapa").
func _registrar_js() -> void:
	var win = JavaScriptBridge.get_interface("window")
	var cb1 = JavaScriptBridge.create_callback(func(a): teleportar(float(a[0]), float(a[1])))
	var cb2 = JavaScriptBridge.create_callback(func(a): Game.flags[str(a[0])] = true; _aplicar_portoes(false))
	_js_cbs = [cb1, cb2]
	win.nvTeleport = cb1
	win.nvFlag = cb2

# ------------------------------------------------------------------ construção
func _construir_mundo() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.015, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.45, 0.55)
	env.ambient_light_energy = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-25, 20, 0)
	sol.light_energy = 0.5
	sol.light_color = Color("ffe0c0")
	add_child(sol)
	cenario = Cenario.new()
	add_child(cenario)
	cenario.construir(mapa)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAM_TAM
	camera.rotation_degrees = Vector3(-8, 0, 0)
	camera.far = 90.0
	camera.near = 1.0
	camera.current = true
	add_child(camera)
	_criar_particulas()

func _criar_particulas() -> void:
	particulas = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(15, 8, 3)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, 0.05, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	particulas.process_material = pm
	var q := SphereMesh.new()
	q.radius = 0.06
	q.height = 0.12
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("ffd070")
	q.material = mat
	particulas.draw_pass_1 = q
	particulas.amount = 50
	particulas.lifetime = 7.0
	particulas.preprocess = 6.0
	particulas.visibility_aabb = AABB(Vector3(-20, -12, -6), Vector3(40, 24, 12))
	add_child(particulas)

func _criar_herois() -> void:
	for k in Game.PARTY_ORDER:
		var h := Hero.new()
		add_child(h)
		h.setup(k, self)
		h.morreu.connect(_heroi_morreu)
		h.ativar(false)
		herois[k] = h
	var primeiro := ""
	for k in Game.PARTY_ORDER:
		if Game.vivos[k]:
			primeiro = k
			break
	_ativar(primeiro, _pos_banco(Game.respawn))

func _pos_banco(id: String) -> Vector3:
	for b in mapa.bancos:
		if b["id"] == id:
			return Vector3(b["x"] + 0.5, b["y"], 0.5)
	return Vector3(mapa.inicio.x, mapa.inicio.y, 0.5)

func _ativar(k: String, pos: Vector3) -> void:
	var face_ant := 1.0
	for kk in herois.keys():
		if herois[kk].ativo:
			face_ant = herois[kk].face
		herois[kk].ativar(false)
	ativo_k = k
	var h: Hero = herois[k]
	h.ativar(true)
	h.global_position = Vector3(pos.x, pos.y, 0.5)
	h.velocity = Vector3.ZERO
	h.face = face_ant
	h.sprite.flip_h = face_ant < 0.0
	h.seguro = h.global_position
	h.invuln_t = 0.6
	Fx.ring(self, pos, 2.0, Game.HEROES[k]["cor"], 0.3)

func _trocar(k: String) -> void:
	if troca_cd > 0.0 or k == ativo_k or not Game.vivos.get(k, false):
		return
	troca_cd = 0.8
	var pos: Vector3 = herois[ativo_k].global_position
	_ativar(k, pos)

func _ciclo(passo: int) -> void:
	var ordem: Array = Game.PARTY_ORDER
	var i := ordem.find(ativo_k)
	for n in range(1, ordem.size()):
		var k: String = ordem[(i + passo * n + ordem.size() * 3) % ordem.size()]
		if Game.vivos[k]:
			_trocar(k)
			return

func _heroi_morreu(k: String) -> void:
	Game.mortes_total += 1
	Fx.popup(self, herois[k].global_position, "%s CAIU" % Game.HEROES[k]["nome"], Color("ff4444"), 48)
	if k != ativo_k:
		return
	var pos: Vector3 = herois[k].global_position
	for kk in Game.PARTY_ORDER:
		if Game.vivos[kk]:
			troca_cd = 0.0
			_ativar(kk, pos)
			return
	_derrota()

# ------------------------------------------------------------------ portões, salas, bancos
func _estado_portao(id: String) -> bool:
	match id:
		"barreira": return not Game.flags.get("mapa", false)
		"cripta": return not Game.flags.get("cripta_aberta", false)
		"atalho": return not Game.flags.get("atalho", false)
		"besta_chao": return not Game.flags.get("besta", false)
		"valerius_e": return not Game.flags.get("valerius", false)
	return false

func _aplicar_portoes(animar: bool) -> void:
	for id in mapa.portoes.keys():
		var f := _estado_portao(id)
		mapa.definir_portao(id, f)
		cenario.atualizar_portao(id, f, animar)

func set_portao(id: String, fechado: bool) -> void:
	mapa.definir_portao(id, fechado)
	cenario.atualizar_portao(id, fechado, true)

func _estado_sala(id: String) -> Dictionary:
	if not salas_estado.has(id):
		salas_estado[id] = {"estado": 0, "inim": []}
	return salas_estado[id]

func _resetar_salas() -> void:
	for id in salas_estado.keys():
		for e in salas_estado[id]["inim"]:
			if is_instance_valid(e):
				e.queue_free()
		salas_estado[id] = {"estado": 0, "inim": []}

func _transmitir_salas(h: Hero) -> void:
	var px := h.global_position.x
	var py := h.global_position.y
	for s in mapa.salas:
		if s["inimigos"].is_empty():
			continue
		if px < s["x0"] - 4 or px > s["x1"] + 5 or py < s["y0"] - 4 or py > s["y1"] + 5:
			continue
		var est := _estado_sala(s["id"])
		if est["estado"] == 0:
			est["estado"] = 1
			for e in s["inimigos"]:
				var x: float = e[1]
				var tipo: String = e[0]
				var y: float
				if Enemy.TIPOS[tipo].get("voa", false):
					y = (e[2] if e.size() > 2 else mapa.chao_em(x, s["y1"]) + 3.0)
				else:
					y = mapa.chao_em(x, s["y1"])
				var n := _criar_inimigo(tipo, Vector3(x, y, 0.3), false)
				est["inim"].append(n)
		elif est["estado"] == 1:
			var vivos := false
			for e in est["inim"]:
				if is_instance_valid(e):
					vivos = true
					break
			if not vivos:
				est["estado"] = 2

func _criar_inimigo(tipo: String, pos: Vector3, agressivo: bool) -> Enemy:
	var e := Enemy.new()
	add_child(e)
	e.setup(tipo, self, agressivo)
	e.global_position = pos
	e.casa_x = pos.x
	e.morto.connect(_inimigo_morto)
	return e

func spawnar(lista: Array, perto: Vector3 = Vector3.ZERO) -> void:
	for tipo in lista:
		var x: float
		var y: float
		if perto != Vector3.ZERO:
			x = perto.x + randf_range(-5.0, 5.0)
			y = perto.y
			if not mapa.caixa_livre(x, y, 0.6, 2.0):
				x = perto.x
		elif not arena.is_empty():
			var sx: Array = arena["spawn_x"]
			x = randf_range(sx[0], sx[1])
			y = mapa.chao_em(x, arena["trig"][3] - 1)
		else:
			continue
		if Enemy.TIPOS[tipo].get("voa", false):
			y += 3.0
		var e := _criar_inimigo(tipo, Vector3(x, y, 0.3), true)
		e.set_meta("arena", true)

func _inimigo_morto(e: Enemy) -> void:
	if e == chefe_ref:
		chefe_ref = null
		barra_chefe.visible = false
		l_chefe.visible = false
		for n in get_tree().get_nodes_in_group("enemies"):
			if n != e and n.has_meta("arena"):
				n.receber_dano(9999.0, Vector3.ZERO, 0.0, 0.0)

# ------------------------------------------------------------------ arenas
func _verificar_arenas(h: Hero) -> void:
	if not arena.is_empty():
		_logica_arena(get_process_delta_time())
		return
	var cx := h.global_position.x
	var cy := h.global_position.y + 1.0
	for a in mapa.arenas:
		if Game.flags.get(a["flag"], false):
			continue
		var r: Array = a["trig"]
		if cx >= r[0] and cx <= r[2] and cy >= r[1] and cy <= r[3]:
			_iniciar_arena(a)
			return

func _iniciar_arena(a: Dictionary) -> void:
	arena = a
	arena_est = {"onda": 0, "pausa": 1.6, "boss": false}
	for g in a["fecha"]:
		set_portao(g, true)
	_banner("%s" % a["nome"], 3.0)
	Fx.popup(self, herois[ativo_k].global_position, "PORTÕES SELADOS", Color("ff6a6a"), 48)

func _logica_arena(delta: float) -> void:
	var vivos := 0
	for n in get_tree().get_nodes_in_group("enemies"):
		if n.has_meta("arena"):
			vivos += 1
	if vivos > 0:
		return
	arena_est["pausa"] -= delta
	if arena_est["pausa"] > 0.0:
		return
	var ondas: Array = arena["ondas"]
	if arena_est["onda"] < ondas.size():
		spawnar(ondas[arena_est["onda"]])
		Fx.popup(self, camera.global_position + Vector3(0, -2, -20), "ONDA %d" % (arena_est["onda"] + 1), Color("ffd0d0"), 60)
		arena_est["onda"] += 1
		arena_est["pausa"] = 2.0
	elif arena["boss"] != "" and not arena_est["boss"]:
		arena_est["boss"] = true
		spawnar([arena["boss"]])
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.chefe:
				chefe_ref = e
		if chefe_ref != null:
			l_chefe.text = chefe_ref.d["nome"]
			l_chefe.visible = true
			barra_chefe.visible = true
	else:
		_vencer_arena()

func _vencer_arena() -> void:
	var a := arena
	Game.flags[a["flag"]] = true
	arena = {}
	chefe_ref = null
	barra_chefe.visible = false
	l_chefe.visible = false
	for g in a["abre"]:
		set_portao(g, false)
	for g in a["fecha"]:
		if a["id"] != "lyla":
			set_portao(g, false)
	Fx.popup(self, herois[ativo_k].global_position, "VITÓRIA", Color("ffffff"), 70)
	_banner("%s — derrotado" % a["nome"] if a["boss"] != "" else "Os caçadores recuam", 3.5)
	_curar_todos(0.4)
	if a["id"] == "lyla":
		fim_t = 3.0
		return
	var cfg: Dictionary = Game.SETORES[a["setor"]]
	if not cfg["outro"].is_empty():
		get_tree().create_timer(1.8).timeout.connect(func(): historia_pedida.emit(cfg["outro"], "Fase concluída"))

func _curar_todos(frac: float) -> void:
	for k in Game.HEROES.keys():
		if Game.vivos[k]:
			Game.hp[k] = minf(Game.hp_max(k), Game.hp[k] + Game.hp_max(k) * frac)
			Game.contam[k] = 0.0

func _resetar_arena() -> void:
	if arena.is_empty():
		return
	for n in get_tree().get_nodes_in_group("enemies"):
		if n.has_meta("arena"):
			n.remove_from_group("enemies")
			n.queue_free()
	for g in arena["fecha"]:
		set_portao(g, false)
	arena = {}
	chefe_ref = null
	barra_chefe.visible = false
	l_chefe.visible = false

# ------------------------------------------------------------------ morte e descanso
func _derrota() -> void:
	if _derrotado:
		return
	_derrotado = true
	_banner("A LUZ SE APAGA...", 3.0)
	var tw := create_tween()
	tw.tween_property(flash, "color", Color(0, 0, 0, 1), 0.7)
	tw.tween_callback(_reviver)
	tw.tween_property(flash, "color", Color(0, 0, 0, 0), 0.8)
	tw.tween_callback(func(): _derrotado = false)

func _reviver() -> void:
	_resetar_arena()
	_resetar_salas()
	for n in get_tree().get_nodes_in_group("enemies"):
		n.remove_from_group("enemies")
		n.queue_free()
	for k in Game.HEROES.keys():
		Game.vivos[k] = true
		Game.hp[k] = Game.hp_max(k)
		Game.contam[k] = 0.0
	var pos := _pos_banco(Game.respawn)
	var primeiro: String = Game.PARTY_ORDER[0]
	_ativar(primeiro, pos)
	_aplicar_portoes(false)
	_atualizar_camera(1.0, true)

func _descansar(b: Dictionary) -> void:
	Game.respawn = b["id"]
	for k in Game.HEROES.keys():
		Game.vivos[k] = true
		Game.hp[k] = Game.hp_max(k)
		Game.contam[k] = 0.0
	_resetar_salas()
	for n in get_tree().get_nodes_in_group("enemies"):
		n.remove_from_group("enemies")
		n.queue_free()
	Fx.ring(self, herois[ativo_k].global_position, 5.0, Color("ffb050"), 0.6)
	Fx.popup(self, herois[ativo_k].global_position, "DESCANSO — grupo restaurado", Color("ffd89a"), 40)
	_banner("Fogueira acesa: %s" % b["nome"], 3.0)
	var tw := create_tween()
	flash.color = Color(1, 0.8, 0.5, 0.0)
	tw.tween_property(flash, "color", Color(1, 0.8, 0.5, 0.35), 0.2)
	tw.tween_property(flash, "color", Color(1, 0.8, 0.5, 0.0), 0.5)

# ------------------------------------------------------------------ itens e gatilhos
func _atualizar_itens(h: Hero) -> void:
	for it in mapa.itens:
		var id: String = it["id"]
		var coletado: bool = Game.flags.get(id, false)
		var visivel: bool = not coletado and (it["req"] == "" or Game.flags.get(it["req"], false))
		if visivel and not itens_nos.has(id):
			itens_nos[id] = _criar_item_no(it)
		elif not visivel and itens_nos.has(id):
			if is_instance_valid(itens_nos[id]):
				itens_nos[id].queue_free()
			itens_nos.erase(id)
		if visivel and absf(h.global_position.x - (it["x"] + 0.5)) < 1.3 and absf(h.centro().y - (it["y"] + 1.0)) < 2.2:
			_coletar(it)

func _criar_item_no(it: Dictionary) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.global_position = Vector3(it["x"] + 0.5, it["y"] + 1.1, 0.5)
	var cor := Color("ff5a7a") if it["tipo"] == "coracao" else (Color("7dff9a") if it["tipo"] == "habilidade" else Color("ffe14d"))
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.35
	s.height = 0.7
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.emission_enabled = true
	mat.emission = cor
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	n.add_child(m)
	var l := OmniLight3D.new()
	l.light_color = cor
	l.omni_range = 6.0
	l.light_energy = 1.6
	n.add_child(l)
	var lb := Label3D.new()
	lb.text = it["nome"]
	lb.font_size = 40
	lb.pixel_size = 0.01
	lb.outline_size = 10
	lb.modulate = cor
	lb.position = Vector3(0, 1.0, 0)
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.add_child(lb)
	return n

func _coletar(it: Dictionary) -> void:
	var id: String = it["id"]
	Game.flags[id] = true
	match it["tipo"]:
		"coracao":
			Game.bonus_hp += 15.0
			for k in Game.HEROES.keys():
				if Game.vivos[k]:
					Game.hp[k] = minf(Game.hp_max(k), Game.hp[k] + 15.0)
		"chave":
			if id == "mapa":
				set_portao("barreira", false)
	Fx.ring(self, herois[ativo_k].global_position, 4.0, Color("ffe14d"), 0.5)
	_banner("%s\n%s" % [it["nome"], it["texto"]], 7.0)

func _atualizar_gatilhos(h: Hero) -> void:
	var cx := h.global_position.x
	var cy := h.global_position.y + 0.5
	for g in mapa.gatilhos:
		var r: Array = g["rect"]
		if not (cx >= r[0] and cx <= r[2] + 1 and cy >= r[1] and cy <= r[3] + 1):
			continue
		match g["acao"]:
			"abrir_atalho":
				if not Game.flags.get("atalho", false):
					Game.flags["atalho"] = true
					set_portao("atalho", false)
					_banner("Você destrava o Portão de Ferro: o atalho para os Túneis de Aethelgard está aberto.", 5.0)
			"abrir_cripta":
				if Game.flags.get("reliquia", false):
					if not Game.flags.get("cripta_aberta", false):
						Game.flags["cripta_aberta"] = true
						set_portao("cripta", false)
						_banner("A Relíquia de Kal-Drak ressoa. Os Portões da Cripta dos Sussurros se abrem.", 5.0)
				else:
					_dica("cripta", "Os Portões da Cripta estão selados. A Relíquia de Kal-Drak pode ser a chave.")
			"dica":
				if not Game.flags.get(g["nao"], false):
					_dica(g["id"], g["texto"])

func _dica(id: String, texto: String) -> void:
	if t_total - _hint_t.get(id, -99.0) > 14.0:
		_hint_t[id] = t_total
		_banner(texto, 5.5)

func _atualizar_bancos(h: Hero) -> void:
	l_prompt.visible = false
	for b in mapa.bancos:
		if absf(h.global_position.x - (b["x"] + 0.5)) < 1.8 and absf(h.global_position.y - b["y"]) < 2.0 and arena.is_empty():
			l_prompt.text = "[S / Seta ↓ ]  Descansar na fogueira".replace("↓", "baixo")
			l_prompt.visible = true
			if Input.is_action_just_pressed("down") and h.no_chao:
				_descansar(b)
			return

# ------------------------------------------------------------------ setor / ambiente
func _ambiente(setor: String, imediato: bool = false) -> void:
	var cfg: Dictionary = Game.SETORES[setor]
	var amb: Color = cfg["ambiente"]
	var fundo: Color = cfg["fundo"]
	if imediato:
		env.ambient_light_color = amb
		env.background_color = fundo
	else:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(env, "ambient_light_color", amb, 1.2)
		tw.tween_property(env, "background_color", fundo, 1.2)
	var pm := particulas.draw_pass_1.material as StandardMaterial3D
	pm.albedo_color = cfg["luz"]

func setor_visitado(id: String) -> bool:
	return Game.flags.get("visto_" + id, false)

func _checar_setor(h: Hero) -> void:
	var s := mapa.setor_de(h.global_position.x, h.global_position.y + 1.0)
	if s == setor_atual:
		return
	setor_atual = s
	_ambiente(s)
	var cfg: Dictionary = Game.SETORES[s]
	if t_total - setor_popup_t > 6.0:
		setor_popup_t = t_total
		l_area.text = cfg["nome"]
		l_sub.text = cfg["cap"]
		_area_t = 4.0
	if not Game.flags.get("visto_" + s, false):
		Game.flags["visto_" + s] = true
		historia_pedida.emit(cfg["intro"], cfg["cap"])

func _banner(texto: String, dur: float) -> void:
	l_banner.text = texto
	_banner_t = dur

# ------------------------------------------------------------------ exploração (névoa do mapa)
func _iniciar_mapa_imagem() -> void:
	_img = Image.create(Mapa.W, Mapa.H, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 0))
	if Game.explorado.size() != Mapa.W * Mapa.H:
		Game.explorado.resize(Mapa.W * Mapa.H)
		Game.explorado.fill(0)
	else:
		for y in range(Mapa.H):
			for x in range(Mapa.W):
				if Game.explorado[y * Mapa.W + x] == 1:
					_pintar(x, y)
	_tex = ImageTexture.create_from_image(_img)
	mini.tex = _tex
	grande.tex = _tex

func _pintar(x: int, y: int) -> void:
	var t := mapa.tile(x, y)
	var cfg: Dictionary = Game.SETORES[mapa.setor_de(x + 0.5, y + 0.5)]
	var c: Color
	if t == 1:
		var r: Color = cfg["rocha"]
		c = Color(r.r * 0.55 + 0.05, r.g * 0.55 + 0.05, r.b * 0.55 + 0.07, 1.0)
	elif t == 2:
		c = Color(0.85, 0.8, 0.6, 1.0)
	elif t == 3:
		c = Color(0.9, 0.2, 0.2, 1.0)
	else:
		var l: Color = cfg["luz"]
		c = Color(l.r * 0.28, l.g * 0.28, l.b * 0.28, 0.95)
	_img.set_pixel(x, Mapa.H - 1 - y, c)

func explorado_em(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= Mapa.W or y >= Mapa.H:
		return false
	return Game.explorado[y * Mapa.W + x] == 1

func _revelar(h: Hero) -> void:
	var cx := floori(h.global_position.x)
	var cy := floori(h.global_position.y) + 1
	var mudou := false
	for y in range(cy - 9, cy + 10):
		for x in range(cx - 15, cx + 16):
			if x < 0 or y < 0 or x >= Mapa.W or y >= Mapa.H:
				continue
			if Game.explorado[y * Mapa.W + x] == 0:
				Game.explorado[y * Mapa.W + x] = 1
				_pintar(x, y)
				mudou = true
	if mudou:
		_tex.update(_img)

# ------------------------------------------------------------------ loop
var modal := false

func _process(delta: float) -> void:
	if modal:
		return
	if Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("mapa"):
		if fim_t < 0.0 and not _derrotado:
			_alternar_mapa()
	if get_tree().paused and not mapa_aberto:
		return
	if mapa_aberto:
		grande.queue_redraw()
		return
	t_total += delta
	if fim_t >= 0.0:
		fim_t -= delta
		if fim_t <= 0.0:
			fim_t = -1.0
			terminou.emit(true)
		_atualizar_hud()
		return
	troca_cd = maxf(0.0, troca_cd - delta)
	buff_t = maxf(0.0, buff_t - delta)
	if not _derrotado:
		if Input.is_action_just_pressed("prev"): _ciclo(-1)
		if Input.is_action_just_pressed("next"): _ciclo(1)
		if Input.is_action_just_pressed("h1"): _trocar(Game.PARTY_ORDER[0])
		if Input.is_action_just_pressed("h2"): _trocar(Game.PARTY_ORDER[1])
		if Input.is_action_just_pressed("h3"): _trocar(Game.PARTY_ORDER[2])
	var h: Hero = herois[ativo_k]
	_atualizar_camera(delta, false)
	_transmitir_salas(h)
	_explor_t -= delta
	if _explor_t <= 0.0:
		_explor_t = 0.3
		_revelar(h)
		mini.queue_redraw()
	_far_t -= delta
	if _far_t <= 0.0:
		_far_t = 0.5
		for e in get_tree().get_nodes_in_group("enemies"):
			var longe: bool = absf(e.global_position.x - h.global_position.x) > 60.0 or absf(e.global_position.y - h.global_position.y) > 40.0
			e.process_mode = Node.PROCESS_MODE_DISABLED if longe else Node.PROCESS_MODE_PAUSABLE
	if not _derrotado:
		_checar_setor(h)
		_verificar_arenas(h)
		_atualizar_itens(h)
		_atualizar_gatilhos(h)
		_atualizar_bancos(h)
	cenario.atualizar(camera.global_position, t_total)
	for id in itens_nos.keys():
		var n: Node3D = itens_nos[id]
		if is_instance_valid(n):
			n.position.y += sin(t_total * 3.0 + n.position.x) * 0.004
	_atualizar_hud()

func _atualizar_camera(delta: float, brusco: bool) -> void:
	var h: Hero = herois[ativo_k]
	var meia_h := CAM_TAM * 0.5
	var meia_w := meia_h * 16.0 / 9.0
	var alvo_x := h.global_position.x + h.face * 2.5
	var alvo_y := h.global_position.y + 3.0
	alvo_x = clampf(alvo_x, meia_w - 1.0, Mapa.W - meia_w + 1.0)
	alvo_y = clampf(alvo_y, meia_h - 1.5, Mapa.H - meia_h + 1.0)
	var cx := camera.position.x
	var cy := camera.position.y - CAM_Z * tan(deg_to_rad(8.0))
	if brusco:
		cx = alvo_x
		cy = alvo_y
	else:
		cx = lerpf(cx, alvo_x, 1.0 - exp(-7.0 * delta))
		cy = lerpf(cy, alvo_y, 1.0 - exp(-5.0 * delta))
	camera.position = Vector3(cx, cy + CAM_Z * tan(deg_to_rad(8.0)), CAM_Z)
	particulas.global_position = Vector3(cx, cy, -1.0)

func _alternar_mapa() -> void:
	mapa_aberto = not mapa_aberto
	painel_mapa.visible = mapa_aberto
	get_tree().paused = mapa_aberto
	if mapa_aberto:
		grande.queue_redraw()
		l_obj.text = "Objetivo: " + objetivo()

func objetivo() -> String:
	var f := Game.flags
	if not f.get("a_pateo", false):
		return "Siga até o Pátio da Estalagem e enfrente os caçadores de Lyla."
	if not f.get("mapa", false):
		return "Entre na Floresta de Oakhaven. Procure o Mapa Roubado na Cabana do Caçador, no alto da clareira. (Um buraco no chão da clareira leva à Confluência Submersa.)"
	if not f.get("besta", false):
		return "Atravesse a Barreira de Sangue e suba as Ruínas de Kal-Drak. A Besta de Transfusão guarda o altar."
	if not f.get("reliquia", false):
		return "Recolha a Relíquia de Kal-Drak no altar da Besta."
	if not f.get("propulsor", false) and not f.get("valerius", false):
		return "Desça pelo poço da Besta até a Marcha. O Poço da Cripta exige um segundo pulo: procure a oficina goblin nos Túneis de Aethelgard (desça pelo poço no chão da Confluência Submersa, no centro do mundo)."
	if not f.get("valerius", false):
		return "Cruze os Portões da Cripta, suba o Poço e derrote Lorde Valerius no Salão do Ritual."
	if not f.get("lyla", false):
		return "Suba a Escadaria Carmesim. Lyla, a Rainha da Ruína, aguarda no Altar."
	return "O Beijo da Morte foi quebrado."

# ------------------------------------------------------------------ HUD
func _rotulo(pos: Vector2, tam: int, cor: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", tam)
	l.modulate = cor
	hud.add_child(l)
	return l

func _construir_hud() -> void:
	var vig := CanvasLayer.new()
	vig.layer = 0
	add_child(vig)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.45, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.62)])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 256
	gtex.height = 256
	var vt := TextureRect.new()
	vt.texture = gtex
	vt.set_anchors_preset(Control.PRESET_FULL_RECT)
	vt.stretch_mode = TextureRect.STRETCH_SCALE
	vt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.add_child(vt)
	hud = CanvasLayer.new()
	add_child(hud)
	var y := 10
	for k in Game.PARTY_ORDER:
		var nome := _rotulo(Vector2(12, y), 16)
		var b := ProgressBar.new()
		b.position = Vector2(12, y + 22)
		b.size = Vector2(230, 12)
		b.show_percentage = false
		b.max_value = Game.hp_max(k)
		b.modulate = Color(0.95, 0.3, 0.3)
		hud.add_child(b)
		var c := ProgressBar.new()
		c.position = Vector2(12, y + 36)
		c.size = Vector2(230, 6)
		c.show_percentage = false
		c.max_value = 100.0
		c.modulate = Color(0.8, 0.2, 0.9)
		hud.add_child(c)
		var cds := _rotulo(Vector2(250, y + 4), 13)
		linhas[k] = {"nome": nome, "hp": b, "contam": c, "cds": cds}
		y += 62
	l_status = _rotulo(Vector2(12, y + 2), 14, Color(1, 0.93, 0.7))
	# minimapa
	mini = MiniMapa.new()
	mini.mundo = self
	mini.position = Vector2(1280 - 292, 12)
	mini.size = Vector2(280, 150)
	hud.add_child(mini)
	# títulos de área e banner
	l_area = _rotulo(Vector2(0, 150), 44, Color("f0d890"))
	l_area.size = Vector2(1280, 60)
	l_area.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_area.modulate.a = 0.0
	l_sub = _rotulo(Vector2(0, 205), 20, Color(1, 1, 1))
	l_sub.size = Vector2(1280, 30)
	l_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_sub.modulate.a = 0.0
	l_banner = _rotulo(Vector2(240, 560), 20, Color("ffe8b0"))
	l_banner.size = Vector2(800, 90)
	l_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_banner.modulate.a = 0.0
	l_prompt = _rotulo(Vector2(440, 520), 22, Color("ffd89a"))
	l_prompt.size = Vector2(400, 30)
	l_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_prompt.visible = false
	l_chefe = _rotulo(Vector2(440, 640), 20)
	l_chefe.visible = false
	barra_chefe = ProgressBar.new()
	barra_chefe.position = Vector2(340, 672)
	barra_chefe.size = Vector2(600, 18)
	barra_chefe.show_percentage = false
	barra_chefe.modulate = Color(1, 0.2, 0.25)
	barra_chefe.visible = false
	hud.add_child(barra_chefe)
	l_ajuda = _rotulo(Vector2(12, 696), 13, Color(1, 1, 1, 0.6))
	l_ajuda.text = "A/D mover | Espaço/W pular (2x com Propulsor) | J atacar | K/L habilidades | I suprema | Q/E ou 1-2-3 trocar | S/baixo descansar | M mapa"
	# tela de mapa completo (pausa)
	painel_mapa = Control.new()
	painel_mapa.set_anchors_preset(Control.PRESET_FULL_RECT)
	painel_mapa.visible = false
	hud.add_child(painel_mapa)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.88)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	painel_mapa.add_child(fundo)
	grande = MiniMapa.new()
	grande.mundo = self
	grande.grande = true
	grande.position = Vector2(40, 110)
	grande.size = Vector2(1200, 320)
	painel_mapa.add_child(grande)
	var tm := Label.new()
	tm.text = "MAPA DE NOVAÉRIA — Esc / M para voltar"
	tm.position = Vector2(40, 40)
	tm.add_theme_font_size_override("font_size", 28)
	tm.modulate = Color("f0d890")
	painel_mapa.add_child(tm)
	l_obj = Label.new()
	l_obj.position = Vector2(40, 450)
	l_obj.size = Vector2(1200, 80)
	l_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_obj.add_theme_font_size_override("font_size", 20)
	painel_mapa.add_child(l_obj)
	var lg := Label.new()
	lg.text = "Branco: você   Laranja: fogueira   Amarelo: item   Vermelho: chefe\nItens: Propulsor (2º pulo), Mapa Roubado, Relíquia de Kal-Drak, Fragmentos de Coração"
	lg.position = Vector2(40, 540)
	lg.size = Vector2(1200, 60)
	lg.add_theme_font_size_override("font_size", 16)
	lg.modulate = Color(1, 1, 1, 0.75)
	painel_mapa.add_child(lg)
	flash = ColorRect.new()
	flash.color = Color(0, 0, 0, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)

func _atualizar_hud() -> void:
	for k in Game.PARTY_ORDER:
		var ln: Dictionary = linhas[k]
		var h: Hero = herois[k]
		var nome: String = Game.HEROES[k]["nome"]
		if not Game.vivos[k]:
			nome += "  (caído)"
		ln["nome"].text = ("> " if k == ativo_k else "   ") + nome
		ln["nome"].modulate = Game.HEROES[k]["cor"] if k == ativo_k else Color(0.75, 0.75, 0.75)
		ln["hp"].max_value = Game.hp_max(k)
		ln["hp"].value = Game.hp[k]
		ln["contam"].value = Game.contam[k]
		if k == ativo_k:
			var t := "Atq  K:%s  L:%s  Ult:%s" % [_cdtxt(h.cd["sk1"]), _cdtxt(h.cd["sk2"]), _cdtxt(h.cd["ult"])]
			if k == "ziggs":
				t += "   Pressão %d%%" % int(h.pressao)
			ln["cds"].text = t
		else:
			ln["cds"].text = ""
	var itens := []
	if Game.flags.get("propulsor", false): itens.append("Propulsor")
	if Game.flags.get("mapa", false): itens.append("Mapa")
	if Game.flags.get("reliquia", false): itens.append("Relíquia")
	l_status.text = "Vida +%d   %s" % [int(Game.bonus_hp), "  ".join(itens)]
	if chefe_ref != null and is_instance_valid(chefe_ref):
		barra_chefe.max_value = chefe_ref.max_hp
		barra_chefe.value = chefe_ref.hp
	_banner_t = maxf(0.0, _banner_t - get_process_delta_time())
	l_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
	_area_t = maxf(0.0, _area_t - get_process_delta_time())
	var a := clampf(minf(_area_t, 4.0 - _area_t) * 1.4, 0.0, 1.0) if _area_t > 0.0 else 0.0
	l_area.modulate.a = a
	l_sub.modulate.a = a * 0.9

func _cdtxt(v: float) -> String:
	return "OK" if v <= 0.05 else "%.0fs" % v

# ------------------------------------------------------------------ utilidades de teste
func teleportar(x: float, y: float) -> void:
	var h: Hero = herois[ativo_k]
	h.global_position = Vector3(x, y, 0.5)
	h.velocity = Vector3.ZERO
	_atualizar_camera(1.0, true)
