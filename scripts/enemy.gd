class_name Enemy
extends CharacterBody3D
## Inimigos do Culto do Sangue de Ferro + chefes (Besta, Valerius, Lyla).

signal morto(inimigo: Enemy)

const TIPOS := {
	"sanguessuga": {"nome": "Sanguessuga de Sucata", "hp": 40.0, "vel": 3.6, "dano": 8.0, "alc": 1.5, "cd": 1.1, "esc": 0.04, "contam": 6.0, "raio": 0.5},
	"carnical": {"nome": "Carniçal de Caldeira", "hp": 110.0, "vel": 1.7, "dano": 14.0, "alc": 1.8, "cd": 1.6, "esc": 0.05, "contam": 10.0, "raio": 0.8},
	"succubus": {"nome": "Súcubo de Sangue", "hp": 60.0, "vel": 2.8, "dano": 10.0, "alc": 8.0, "cd": 2.0, "esc": 0.04, "contam": 12.0, "raio": 0.5, "voa": true},
	"irma": {"nome": "Irmã da Agulha", "hp": 55.0, "vel": 3.4, "dano": 14.0, "alc": 6.0, "cd": 3.0, "esc": 0.04, "contam": 8.0, "raio": 0.5},
	"capelao": {"nome": "Capelão de Ferro", "hp": 190.0, "vel": 1.6, "dano": 16.0, "alc": 3.0, "cd": 3.6, "esc": 0.05, "contam": 10.0, "raio": 0.8},
	"besta": {"nome": "A Besta de Transfusão", "hp": 650.0, "vel": 2.4, "dano": 22.0, "alc": 2.6, "cd": 2.4, "esc": 0.08, "contam": 14.0, "raio": 1.4, "boss": true},
	"valerius": {"nome": "Lorde Valerius", "hp": 1000.0, "vel": 2.6, "dano": 26.0, "alc": 3.0, "cd": 2.2, "esc": 0.07, "contam": 16.0, "raio": 1.1, "boss": true},
	"lyla": {"nome": "Lyla, a Rainha da Ruína", "hp": 1300.0, "vel": 3.4, "dano": 20.0, "alc": 2.5, "cd": 2.0, "esc": 0.06, "contam": 18.0, "raio": 0.9, "boss": true},
}

var chave := "sanguessuga"
var d := {}
var hp := 40.0
var max_hp := 40.0
var raio_corpo := 0.5
var sprite: Sprite3D
var anim: Anim
var _face_a := 1.0
var level: Node = null
var atk_t := 1.0
var estado := "persegue"      # persegue, preparo, dash, giro, drena
var estado_t := 0.0
var stun_t := 0.0
var silencio_t := 0.0
var expiacao_t := 0.0
var knock := Vector3.ZERO
var skill_t := 4.0
var fase2 := false
var dano_no_preparo := 0.0
var alvo_dash := Vector3.ZERO
var heal_t := 2.0
var chefe := false
var base_y := 1.0
var meia := 0.4
var alt := 2.0
var mv := Vector3.ZERO          # intenção de movimento da IA neste quadro
var vy := 0.0
var no_chao := false
var voa := false
var aggro := false
var casa_x := 0.0
var patrulha := 1.0
var dir2 := Vector3.RIGHT       # direção 2D para o alvo (mira)
var pulo_cd := 0.0
var flash_t := 0.0
var bateu := false
var mapa: Mapa = null

func centro() -> Vector3:
	return global_position + Vector3(0, alt * 0.5, 0)

func setup(k: String, lvl: Node, ja_agressivo: bool = false) -> void:
	chave = k
	level = lvl
	d = TIPOS[k]
	hp = d["hp"]
	max_hp = hp
	raio_corpo = d["raio"]
	chefe = d.get("boss", false)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	voa = d.get("voa", false)
	aggro = ja_agressivo or chefe
	mapa = lvl.mapa
	alt = Art.ALTURA.get(k, 2.2) * 0.85
	meia = maxf(0.35, raio_corpo * 0.7)
	sprite = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	Art.configurar(sprite, k)
	base_y = sprite.position.y
	add_child(sprite)
	if not voa:
		anim = Anim.new(sprite, k)
	var luz := OmniLight3D.new()
	luz.light_color = Color("ff2a3a")
	luz.omni_range = 3.0 if not chefe else 6.0
	luz.light_energy = 0.8 if not chefe else 1.6
	luz.position.y = 1.5
	add_child(luz)
	add_to_group("enemies")
	atk_t = randf_range(0.6, 1.6)

func _alvo() -> Node3D:
	var l := get_tree().get_nodes_in_group("player")
	return l[0] if l.size() > 0 else null

func _physics_process(delta: float) -> void:
	var alvo := _alvo()
	stun_t = maxf(0.0, stun_t - delta)
	silencio_t = maxf(0.0, silencio_t - delta)
	expiacao_t = maxf(0.0, expiacao_t - delta)
	atk_t = maxf(0.0, atk_t - delta)
	pulo_cd = maxf(0.0, pulo_cd - delta)
	flash_t = maxf(0.0, flash_t - delta)
	skill_t -= delta
	sprite.modulate = Color(1, 1, 1)
	if flash_t > 0.0:
		sprite.modulate = Color(2.0, 1.6, 1.6)
	if stun_t > 0.0:
		sprite.modulate = Color(0.7, 0.7, 1.0)
	if expiacao_t > 0.0:
		sprite.modulate = sprite.modulate.lerp(Color(1.4, 1.3, 0.7), 0.5)
	if silencio_t > 0.0:
		sprite.modulate = sprite.modulate.lerp(Color(0.6, 0.6, 0.6), 0.6)
	knock = knock.move_toward(Vector3.ZERO, 18.0 * delta)
	mv = Vector3.ZERO
	if alvo != null:
		var para: Vector3 = Fx.plano_xz(alvo.centro() - centro())
		var dist := para.length()
		dir2 = para.normalized() if dist > 0.01 else Vector3.RIGHT
		var dirh := Vector3(signf(para.x), 0, 0)
		if not aggro and absf(para.x) < 15.0 and absf(para.y) < 7.0 and dist < 17.0:
			aggro = true
		elif aggro and not chefe and dist > 40.0:
			aggro = false
		if stun_t <= 0.0:
			if aggro:
				if absf(dirh.x) > 0.1:
					sprite.flip_h = dirh.x < 0.0
				if chave == "capelao":
					heal_t -= delta
					if heal_t <= 0.0:
						heal_t = 2.0
						for e in get_tree().get_nodes_in_group("enemies"):
							if e != self and Fx.plano_xz(e.global_position - global_position).length() < 5.0:
								e.hp = minf(e.max_hp, e.hp + 8.0)
								Fx.popup(get_parent(), e.global_position, "+8", Color("ff7777"), 30)
				var dd: Vector3 = dir2 if voa else dirh
				match chave:
					"succubus": _ia_succubus(alvo, dd, dist, delta)
					"irma": _ia_irma(alvo, dd, dist, delta)
					"capelao": _ia_capelao(alvo, dd, dist, delta)
					"besta": _ia_besta(alvo, dd, dist, delta)
					"valerius": _ia_valerius(alvo, dd, dist, delta)
					"lyla": _ia_lyla(alvo, dd, dist, delta)
					_: _ia_corpo_a_corpo(alvo, dd, dist, delta)
			else:
				_patrulhar(delta)
	_integrar(delta, alvo)

func _patrulhar(delta: float) -> void:
	if voa:
		sprite.position.y = base_y + 0.45 + 0.2 * sin(Time.get_ticks_msec() * 0.005)
		return
	if absf(global_position.x - casa_x) > 3.5 or bateu:
		patrulha = -signf(global_position.x - casa_x) if absf(global_position.x - casa_x) > 3.5 else -patrulha
	mv.x = patrulha * 1.3
	sprite.flip_h = patrulha < 0.0
	if no_chao and not _ha_chao_adiante(patrulha):
		patrulha = -patrulha
		mv.x = 0.0

func _ha_chao_adiante(lado: float) -> bool:
	var xf := global_position.x + lado * (meia + 0.5)
	return mapa.chao_em(xf, global_position.y + 0.5) > global_position.y - 3.2

func _integrar(delta: float, alvo: Node3D) -> void:
	var v := Vector2(mv.x + knock.x, 0.0)
	if voa:
		v.y = mv.y + knock.y
		vy = 0.0
	else:
		# evita cair em precipícios ao perseguir (exceto chefes)
		if no_chao and not chefe and absf(mv.x) > 0.01 and not _ha_chao_adiante(signf(mv.x)) and (alvo == null or alvo.global_position.y > global_position.y - 2.0):
			v.x = knock.x
		vy = maxf(vy - Mapa.GRAV * delta, -26.0)
		v.y = vy
		# pula obstáculos / plataformas quando o alvo está acima
		if aggro and no_chao and pulo_cd <= 0.0 and alvo != null and stun_t <= 0.0:
			var acima: float = alvo.global_position.y - global_position.y
			if (acima > 1.6 and absf(alvo.global_position.x - global_position.x) < 3.0) or (bateu and acima > 0.5):
				vy = 15.0 if acima > 2.8 else 12.0
				v.y = vy
				pulo_cd = 1.2
				no_chao = false
	var r: Dictionary = mapa.mover(global_position, v * delta, meia, alt, false, not voa)
	global_position = r["pos"]
	global_position.z = 0.3
	bateu = r["bateu_x"]
	if not voa:
		if r["chao"] and vy <= 0.0:
			vy = 0.0
			no_chao = true
		else:
			no_chao = false
		if r["teto"] and vy > 0.0:
			vy = 0.0
	_separar()
	if anim != null:
		if absf(mv.x) > 0.1:
			_face_a = signf(mv.x)
		anim.atualizar(delta, mv.x, vy, no_chao, -1.0 if sprite.flip_h else 1.0, float(d["vel"]))

func _separar() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self:
			var dx: float = global_position.x - e.global_position.x
			var m: float = meia + e.meia
			if absf(dx) < m and absf(global_position.y - e.global_position.y) < 1.5:
				var push := signf(dx) if dx != 0.0 else (1.0 if randf() < 0.5 else -1.0)
				var nx: float = global_position.x + push * (m - absf(dx)) * 0.12
				if mapa.caixa_livre(nx, global_position.y, meia, alt):
					global_position.x = nx

func _mover(dir: Vector3, mult: float = 1.0) -> void:
	if voa:
		mv = dir * d["vel"] * mult
	elif absf(dir.x) > 0.05:
		mv.x = signf(dir.x) * d["vel"] * mult

func _acertar(alvo: Node3D, mult: float = 1.0) -> void:
	if anim != null:
		anim.golpe(0.35, 0.22)
	alvo.receber_dano(d["dano"] * mult, d["contam"], global_position)

# ---- IAs -----------------------------------------------------------------
func _ia_corpo_a_corpo(alvo: Node3D, dir: Vector3, dist: float, _dt: float) -> void:
	if dist > d["alc"]:
		_mover(dir)
	elif atk_t <= 0.0:
		atk_t = d["cd"]
		_acertar(alvo)
		Fx.faiscas(get_parent(), alvo.global_position, Color("ff3355"), 6)
	if chave == "carnical" and false:
		pass

func _ia_succubus(alvo: Node3D, dir: Vector3, dist: float, _dt: float) -> void:
	sprite.position.y = base_y + 0.45 + 0.2 * sin(Time.get_ticks_msec() * 0.005)   # flutua (idle)
	# mantém distância e altura (paira ~2,5 acima do herói)
	var ideal_y: float = alvo.global_position.y + 2.6
	var dy: float = clampf((ideal_y - global_position.y) * 1.6, -3.0, 3.0)
	var dx := 0.0
	if absf(alvo.global_position.x - global_position.x) < 4.5:
		dx = -signf(alvo.global_position.x - global_position.x) * d["vel"]
	elif dist > d["alc"]:
		dx = signf(alvo.global_position.x - global_position.x) * d["vel"]
	mv = Vector3(dx, dy, 0)
	if atk_t <= 0.0 and silencio_t <= 0.0 and dist < 14.0:
		atk_t = d["cd"]
		Proj.criar(get_parent(), "blood", centro(), {"vel": dir * 7.0, "dano": d["dano"], "vida": 2.5, "cor": Color("ff2a66"), "heroi": false, "contam": d["contam"], "raio": 0.4})

func _ia_irma(alvo: Node3D, dir: Vector3, dist: float, dt: float) -> void:
	match estado:
		"persegue":
			if dist > 4.0:
				_mover(dir)
			if atk_t <= 0.0 and dist < d["alc"] and silencio_t <= 0.0:
				estado = "preparo"
				estado_t = 0.6
				alvo_dash = dir
				sprite.modulate = Color(1.5, 0.5, 0.6)
		"preparo":
			estado_t -= dt
			sprite.modulate = Color(1.6, 0.5, 0.6)
			if estado_t <= 0.0:
				estado = "dash"
				estado_t = 0.35
		"dash":
			estado_t -= dt
			mv = alvo_dash * 12.0
			var gh := Sprite3D.new()      # rastro de ghosting
			gh.texture = sprite.texture
			gh.pixel_size = sprite.pixel_size
			gh.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			gh.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			gh.shaded = false
			gh.modulate = Color(1, 0.3, 0.5, 0.45)
			gh.flip_h = sprite.flip_h
			get_parent().add_child(gh)
			gh.global_position = sprite.global_position + Vector3(0, 0, 0.05)
			gh.create_tween().tween_property(gh, "modulate:a", 0.0, 0.3).finished.connect(gh.queue_free)
			if dist < 1.6:
				_acertar(alvo)
				estado_t = 0.0
			if estado_t <= 0.0:
				estado = "persegue"
				atk_t = d["cd"]

func _ia_capelao(alvo: Node3D, dir: Vector3, dist: float, dt: float) -> void:
	match estado:
		"persegue":
			if dist > 2.2:
				_mover(dir)
			if atk_t <= 0.0 and dist < d["alc"] and silencio_t <= 0.0:
				estado = "preparo"
				estado_t = 0.7
		"preparo":
			estado_t -= dt
			sprite.modulate = Color(1.5, 0.8, 0.4)
			if estado_t <= 0.0:
				Fx.ring(get_parent(), global_position, 3.4, Color("ff7a1a"), 0.4)       # giro do incensário
				Fx.faiscas(get_parent(), global_position, Color("ff9a3b"), 20)
				if Fx.plano_xz(alvo.centro() - centro()).length() < 3.4:
					_acertar(alvo)
				estado = "persegue"
				atk_t = d["cd"]

func _ia_besta(alvo: Node3D, dir: Vector3, dist: float, dt: float) -> void:
	if not fase2 and hp < max_hp * 0.5:
		fase2 = true
		Fx.popup(get_parent(), global_position, "A BESTA ENFURECE", Color("ff4444"), 44)
		level.spawnar(["sanguessuga", "sanguessuga"], global_position)
	match estado:
		"persegue":
			_mover(dir, 1.3 if fase2 else 1.0)
			if atk_t <= 0.0 and dist < 7.0:
				estado = "preparo"
				estado_t = 0.8
				alvo_dash = dir
		"preparo":
			estado_t -= dt
			sprite.modulate = Color(1.7, 0.5, 0.5)
			if estado_t <= 0.0:
				estado = "dash"
				estado_t = 0.6
		"dash":
			estado_t -= dt
			mv = alvo_dash * 9.0
			if dist < 2.6:
				_acertar(alvo)
				estado_t = 0.0
			if estado_t <= 0.0:
				Fx.ring(get_parent(), global_position, 3.0, Color("aa2222"), 0.3)
				estado = "persegue"
				atk_t = d["cd"]

func _ia_valerius(alvo: Node3D, dir: Vector3, dist: float, dt: float) -> void:
	if not fase2 and hp < max_hp * 0.5:
		fase2 = true
		Fx.popup(get_parent(), global_position, "NÚCLEOS A VAPOR EM SOBRECARGA", Color("ff8844"), 42)
		level.spawnar(["sanguessuga", "sanguessuga"], global_position)
	match estado:
		"persegue":
			if dist > 2.6:
				_mover(dir)
			if atk_t <= 0.0:
				estado = "preparo"
				estado_t = 0.7
			elif skill_t <= 0.0:
				skill_t = 6.0 if fase2 else 8.0
				for i in range(8 if not fase2 else 12):          # pulso de hemomancia
					var a := TAU * i / (8.0 if not fase2 else 12.0)
					Proj.criar(get_parent(), "blood", centro(), {"vel": Vector3(cos(a), sin(a), 0) * 6.0, "dano": 10.0, "vida": 2.5, "cor": Color("ff2a44"), "heroi": false, "contam": 14.0, "raio": 0.4})
		"preparo":
			estado_t -= dt
			sprite.modulate = Color(1.6, 0.6, 0.6)
			if estado_t <= 0.0:
				Fx.ring(get_parent(), global_position, 3.6, Color("ff3b3b"), 0.35)    # golpe hidráulico
				if Fx.plano_xz(alvo.centro() - centro()).length() < 3.6:
					_acertar(alvo)
				estado = "persegue"
				atk_t = d["cd"] * (0.7 if fase2 else 1.0)

func _ia_lyla(alvo: Node3D, dir: Vector3, dist: float, dt: float) -> void:
	if not fase2 and hp < max_hp * 0.5:
		fase2 = true
		Art.configurar(sprite, "lyla_vampira")
		base_y = sprite.position.y
		Fx.popup(get_parent(), global_position, "A REVELAÇÃO: FORMA DE VAMPIRA", Color("ff1744"), 46)
		Fx.ring(get_parent(), global_position, 8.0, Color("ff1744"), 0.8)
		level.spawnar(["succubus"], global_position)
	match estado:
		"persegue":
			if dist > 2.2:
				_mover(dir, 1.3 if fase2 else 1.0)
			if atk_t <= 0.0 and dist < 3.2:
				_acertar(alvo)
				atk_t = d["cd"] * (0.7 if fase2 else 1.0)
			if skill_t <= 0.0:
				skill_t = 5.0 if fase2 else 6.5
				match randi() % 3:
					0: # Lâmina de Sangue em leque
						var base := atan2(dir2.y, dir2.x)
						for i in range(-2, 3):
							var a := base + i * 0.22
							Proj.criar(get_parent(), "blood", centro(), {"vel": Vector3(cos(a), sin(a), 0) * 8.0, "dano": 12.0, "vida": 2.5, "cor": Color("ff1744"), "heroi": false, "contam": 14.0, "raio": 0.4})
					1: # Passo Nebuloso: teleporta para trás do herói
						Fx.ring(get_parent(), global_position, 2.5, Color("aa0033"), 0.3)
						_teleportar(alvo, -dir.x * 2.2)
						Fx.ring(get_parent(), global_position, 2.5, Color("aa0033"), 0.3)
					2: # Beijo da Morte (canalização que pode ser quebrada)
						estado = "drena"
						estado_t = 1.4
						dano_no_preparo = 0.0
						_teleportar(alvo, -dir.x * 1.6)
						Fx.popup(get_parent(), global_position, "BEIJO DA MORTE...", Color("ff1744"), 44)
		"drena":
			estado_t -= dt
			sprite.modulate = Color(1.7, 0.4, 0.6)
			if dano_no_preparo >= 70.0:
				Fx.popup(get_parent(), global_position, "BEIJO QUEBRADO!", Color("ffffff"), 50)
				Fx.ring(get_parent(), global_position, 4.0, Color("ffffff"), 0.5)
				stun_t = 3.0
				expiacao_t = 3.0
				estado = "persegue"
				atk_t = 2.0
			elif estado_t <= 0.0:
				if Fx.plano_xz(alvo.centro() - centro()).length() < 3.2:
					alvo.receber_dano(30.0, 25.0, global_position, true)
					hp = minf(max_hp, hp + 60.0)
					Fx.popup(get_parent(), global_position, "+60", Color("ff4466"), 40)
				estado = "persegue"
				atk_t = 1.5

# ---- dano ----------------------------------------------------------------
func receber_dano(valor: float, dir: Vector3, kb: float, stun: float) -> void:
	var v := valor
	if expiacao_t > 0.0:
		v *= 1.25
	hp -= v
	if anim != null:
		anim.dano(0.25)
	if estado == "drena":
		dano_no_preparo += v
	knock.x += dir.x * kb * (0.3 if chefe else 1.0)
	if voa:
		knock.y += dir.y * kb * 0.5
	flash_t = 0.08
	if stun > 0.0 and not (chefe and estado == "drena"):
		stun_t = maxf(stun_t, stun * (0.4 if chefe else 1.0))
		if estado in ["preparo"] and not chefe:
			estado = "persegue"      # interrompe o preparo
	Fx.popup(get_parent(), centro() - Vector3(0, alt * 0.5, 0), str(int(v)), Color("ffe08a"), 36)
	if hp <= 0.0:
		_morrer()

func _morrer() -> void:
	if chave == "carnical":       # estouro de vapor escaldante e fluido tóxico
		Fx.ring(get_parent(), global_position, 3.0, Color("e8e8e8"), 0.4)
		for h in get_tree().get_nodes_in_group("player"):
			if Fx.plano_xz(h.centro() - centro()).length() < 3.2:
				h.receber_dano(12.0, 10.0, global_position)
	Fx.faiscas(get_parent(), global_position, Color("ff3355"), 18)
	remove_from_group("enemies")
	morto.emit(self)
	queue_free()

func _teleportar(alvo: Node3D, desloc_x: float) -> void:
	var nx: float = alvo.global_position.x + desloc_x
	var ny: float = alvo.global_position.y
	if mapa.caixa_livre(nx, ny, meia, alt):
		global_position = Vector3(nx, ny, 0.3)
	else:
		global_position = Vector3(alvo.global_position.x - desloc_x, ny, 0.3)
	vy = 0.0
