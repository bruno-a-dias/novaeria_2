class_name Hero
extends CharacterBody3D
## Herói jogável (Bron, Solys Regis, Ziggs Spark). Controlado só quando ativo.

signal morreu(chave: String)

var chave := "bron"
var dados := {}
var hp := 100.0
var max_hp := 100.0
var aim := Vector3(1, 0, 0)
var face := 1.0
var meia := 0.42
var alt := 2.2
var no_chao := false
var coyote := 0.0
var jump_buf := 0.0
var pulos_extra := 0
var desce_t := 0.0
var seguro := Vector3.ZERO
var seguro_t := 0.0
var passo := 0.0
const JUMP_V := 16.5
var ativo := false
var sprite: Sprite3D
var luz: OmniLight3D
var cd := {"atk": 0.0, "sk1": 0.0, "sk2": 0.0, "ult": 0.0}
const CD_MAX := {
	"bron": {"atk": 0.55, "sk1": 6.0, "sk2": 5.0, "ult": 25.0},
	"solys": {"atk": 0.55, "sk1": 7.0, "sk2": 12.0, "ult": 30.0},
	"ziggs": {"atk": 0.28, "sk1": 10.0, "sk2": 7.0, "ult": 28.0},
}
var combo := 0
var combo_t := 0.0
var recup_t := 0.0          # recuperação pesada (Bron): movimento -70%
var guarda_t := 0.0
var parry_t := 0.0
var furia_t := 0.0
var stun_t := 0.0
var invuln_t := 0.0
var pressao := 0.0          # Pressão a Vácuo (Ziggs)
var superaq_t := 0.0
var level: Node = null

func setup(k: String, lvl: Node) -> void:
	chave = k
	level = lvl
	dados = Game.HEROES[k]
	process_mode = Node.PROCESS_MODE_PAUSABLE
	max_hp = Game.hp_max(k)
	hp = Game.hp[k]
	meia = 0.4 if k != "bron" else 0.45
	alt = 1.6 if k == "ziggs" else 2.2
	sprite = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	Art.configurar(sprite, k)
	add_child(sprite)
	luz = OmniLight3D.new()
	luz.omni_range = 4.5
	luz.light_color = Color("ffe89c") if k == "solys" else dados["cor"]
	luz.light_energy = 1.4
	luz.position.y = 1.8
	add_child(luz)
	add_to_group("heroes")

func ativar(on: bool) -> void:
	ativo = on
	visible = on
	process_mode = Node.PROCESS_MODE_PAUSABLE if on else Node.PROCESS_MODE_DISABLED
	if on:
		add_to_group("player")
	else:
		remove_from_group("player")

func _physics_process(delta: float) -> void:
	hp = Game.hp[chave]
	for k in cd.keys():
		cd[k] = maxf(0.0, cd[k] - delta)
	combo_t = maxf(0.0, combo_t - delta)
	if combo_t <= 0.0:
		combo = 0
	recup_t = maxf(0.0, recup_t - delta)
	guarda_t = maxf(0.0, guarda_t - delta)
	parry_t = maxf(0.0, parry_t - delta)
	furia_t = maxf(0.0, furia_t - delta)
	stun_t = maxf(0.0, stun_t - delta)
	invuln_t = maxf(0.0, invuln_t - delta)
	superaq_t = maxf(0.0, superaq_t - delta)
	if chave == "ziggs":
		pressao = maxf(0.0, pressao - 12.0 * delta)
		if pressao >= 100.0 and superaq_t <= 0.0:
			superaq_t = 2.0
			Fx.popup(get_parent(), global_position, "SUPERAQUECEU!", Color("ff8844"), 40)
			receber_dano(8.0, 0.0, global_position, true)
	# Contaminação decai devagar
	Game.contam[chave] = maxf(0.0, Game.contam[chave] - 1.5 * delta)
	var c: float = Game.contam[chave]
	if c >= 80.0:
		hp -= 1.2 * delta
		Game.hp[chave] = hp
	sprite.modulate = Color(1, 1, 1).lerp(Color(1, 0.4, 0.45), c / 160.0)
	if invuln_t > 0.0:
		sprite.modulate.a = 0.55
	if furia_t > 0.0:
		sprite.modulate = sprite.modulate.lerp(Color(1.5, 0.6, 0.5), 0.5)
	luz.light_energy = 1.4 + 0.5 * sin(Time.get_ticks_msec() * 0.006) if chave == "solys" else 1.2
	if not ativo:
		return
	max_hp = Game.hp_max(chave)
	var ax := 0.0 if stun_t > 0.0 else Input.get_axis("left", "right")
	var vel_base: float = dados["vel"]
	var m := 1.0
	if recup_t > 0.0:
		m *= 0.3
	if guarda_t > 0.0:
		m *= 0.4
	if furia_t > 0.0:
		m *= 1.15
	if level != null and level.buff_t > 0.0:
		m *= 1.25
	if Game.contam[chave] >= 50.0:
		m *= 0.9
	var acel := 70.0 if no_chao else 45.0
	velocity.x = move_toward(velocity.x, ax * vel_base * m, acel * delta)
	if absf(ax) > 0.1:
		face = signf(ax)
		sprite.flip_h = face < 0.0
	aim = Vector3(face, 0, 0)
	# pulo (com tolerância de coyote/buffer) e pulo duplo
	desce_t = maxf(0.0, desce_t - delta)
	coyote = 0.11 if no_chao else maxf(0.0, coyote - delta)
	jump_buf = maxf(0.0, jump_buf - delta)
	if stun_t <= 0.0 and Input.is_action_just_pressed("jump"):
		jump_buf = 0.12
	if jump_buf > 0.0 and stun_t <= 0.0:
		if no_chao and Input.is_action_pressed("down") and level.mapa.tile(floori(global_position.x), floori(global_position.y - 0.1)) == 2:
			desce_t = 0.25
			jump_buf = 0.0
		elif coyote > 0.0:
			velocity.y = JUMP_V
			coyote = 0.0
			jump_buf = 0.0
			no_chao = false
			Fx.faiscas(get_parent(), global_position - Vector3(0, 0.8, 0), Color("cccccc"), 4)
		elif Game.flags.get("propulsor", false) and pulos_extra > 0:
			velocity.y = JUMP_V * 0.92
			pulos_extra -= 1
			jump_buf = 0.0
			Fx.ring(get_parent(), global_position - Vector3(0, 0.8, 0), 1.4, Color("9affc8"), 0.25)
	if Input.is_action_just_released("jump") and velocity.y > 6.0:
		velocity.y *= 0.55
	velocity.y = maxf(velocity.y - Mapa.GRAV * delta, -26.0)
	var r: Dictionary = level.mapa.mover(global_position, Vector2(velocity.x, velocity.y) * delta, meia, alt, desce_t > 0.0)
	global_position = r["pos"]
	global_position.z = 0.5
	if r["bateu_x"]:
		velocity.x = 0.0
	if r["teto"] and velocity.y > 0.0:
		velocity.y = 0.0
	if r["chao"] and velocity.y <= 0.0:
		velocity.y = 0.0
		no_chao = true
		pulos_extra = 1
	else:
		no_chao = false
	# animação simples: balanço ao andar, inclinação ao correr
	var base_y: float = Art.ALTURA.get(chave, 2.4) * 0.5
	if no_chao and absf(velocity.x) > 0.5:
		passo += delta * 13.0
		sprite.position.y = base_y + absf(sin(passo)) * 0.07
	else:
		sprite.position.y = base_y
	sprite.rotation.z = lerpf(sprite.rotation.z, -velocity.x * 0.012, 10.0 * delta)
	# armadilhas de espinhos
	if no_chao:
		seguro_t -= delta
		if seguro_t <= 0.0 and not level.mapa.espinhos_em(global_position.x, global_position.y, meia, alt):
			seguro = global_position
			seguro_t = 0.35
	if level.mapa.espinhos_em(global_position.x, global_position.y, meia, alt) and invuln_t <= 0.0:
		receber_dano(12.0, 0.0, Vector3.ZERO, true)
		if seguro != Vector3.ZERO:
			global_position = seguro
		velocity = Vector3.ZERO
	if Input.is_action_pressed("atk") and cd["atk"] <= 0.0:
		_atacar()
	if Input.is_action_just_pressed("sk1") and cd["sk1"] <= 0.0:
		_skill1()
	if Input.is_action_just_pressed("sk2") and cd["sk2"] <= 0.0:
		_skill2()
	if Input.is_action_just_pressed("ult") and cd["ult"] <= 0.0:
		_ult()

func centro() -> Vector3:
	return global_position + Vector3(0, alt * 0.5, 0)

func _aim_alvo() -> Vector3:
	var md := 13.0
	var melhor := Vector3.ZERO
	var ok := false
	for e in _inimigos():
		var v: Vector3 = Fx.plano_xz(e.centro() - centro())
		if v.x * face > 0.0 and v.length() < md and absf(v.y) < absf(v.x) * 1.6 + 1.5:
			md = v.length()
			melhor = v
			ok = true
	if ok:
		return melhor.normalized()
	return Vector3(face, 0, 0)

func _frente_livre(dist: float) -> float:
	var d := dist
	while d > 0.5 and not level.mapa.caixa_livre(global_position.x + face * d, global_position.y, 0.5, 1.0):
		d -= 0.5
	return d

func dmg_mult() -> float:
	var m := 1.0
	if furia_t > 0.0:
		m *= 1.6
	return m

func _cooldown(k: String, mult: float = 1.0) -> void:
	cd[k] = CD_MAX[chave][k] * mult

func _inimigos() -> Array:
	return get_tree().get_nodes_in_group("enemies")

func _cone(alcance: float, cos_min: float, d: float, kb: float, stun: float) -> int:
	var n := 0
	for e in _inimigos():
		var v: Vector3 = Fx.plano_xz(e.centro() - centro())
		if v.length() <= alcance + e.meia and absf(v.y) < alcance * 0.9 + 0.8 and (v.length() < 0.6 or v.normalized().dot(aim) >= cos_min):
			e.receber_dano(d * dmg_mult(), v.normalized(), kb, stun)
			n += 1
	return n

# ------------------------------------------------------------------ ataques básicos
func _atacar() -> void:
	match chave:
		"bron":
			var golpe := combo
			combo = (combo + 1) % 3
			combo_t = 1.0
			var d: float = [18.0, 18.0, 32.0][golpe]
			var stun: float = [0.2, 0.2, 0.7][golpe]
			var kb: float = [3.0, 3.0, 8.0][golpe]
			_cooldown("atk", 1.0 if golpe < 2 else 1.4)
			recup_t = 0.45 if golpe < 2 else 0.6
			Fx.ring(get_parent(), global_position + aim * 1.0, 1.8, Color("ddd"), 0.2)
			_cone(2.4, 0.2, d, kb, stun)
		"solys":
			_cooldown("atk")
			# Chicote de Chamas: linha reta, puxa o primeiro alvo e aplica Expiação
			var alvo: Node3D = null
			var md := 6.5
			var dir_c := _aim_alvo()
			var perp := Vector3(-dir_c.y, dir_c.x, 0)
			for e in _inimigos():
				var v: Vector3 = Fx.plano_xz(e.centro() - centro())
				var along := v.dot(dir_c)
				var lateral := absf(v.dot(perp))
				if along > 0.0 and along < md and lateral < 1.3:
					md = along
					alvo = e
			for i in range(6):
				Fx.faiscas(get_parent(), global_position + dir_c * (0.8 + i * 1.0) - Vector3(0, 0.0, 0), Color("c0c0c0"), 3)
			if alvo != null:
				alvo.receber_dano(14.0 * dmg_mult(), dir_c, 0.0, 0.1)
				alvo.expiacao_t = 4.0
				var nx := global_position.x + face * 1.6
				if level.mapa.caixa_livre(nx, alvo.global_position.y, alvo.meia, alvo.alt):
					alvo.global_position.x = nx
		"ziggs":
			_cooldown("atk", 0.8 if level.buff_t > 0.0 else 1.0)
			if superaq_t > 0.0:
				return
			var mult := 1.5 if pressao > 60.0 else 1.0
			pressao += 6.0
			var dir_z := _aim_alvo()
			Proj.criar(get_parent(), "shard", centro() + dir_z * 0.6, {"vel": dir_z * 16.0, "dano": 10.0 * mult * dmg_mult(), "vida": 1.1, "cor": Color("ffb347"), "heroi": true})

# ------------------------------------------------------------------ habilidades
func _skill1() -> void:
	match chave:
		"bron":  # Impacto de Runas
			_cooldown("sk1")
			recup_t = 0.5
			Fx.ring(get_parent(), global_position + aim * 1.5, 3.6, Color("ff6a3d"), 0.3)
			Fx.popup(get_parent(), global_position, "IMPACTO DE RUNAS", Color("ff9a6a"), 36)
			_cone(3.8, 0.0, 40.0, 9.0, 0.8)
		"solys":  # Pira de Julgamento
			_cooldown("sk1")
			var pos := global_position + aim * _frente_livre(4.0)
			pos.y = level.mapa.chao_em(pos.x, pos.y + 1.0)
			var p := Proj.criar(get_parent(), "pira", pos, {"vida": 1.0, "cor": Color("ffd34d"), "raio": 0.3})
			p.explodir_em(0.4, 2.8, 45.0 * dmg_mult())
			Fx.ring(get_parent(), pos, 1.0, Color("ffd34d"), 0.4)
		"ziggs":  # Torreta de Pressão a Vácuo
			if superaq_t > 0.0: return
			_cooldown("sk1")
			pressao += 25.0
			var tp := global_position + aim * _frente_livre(1.2)
			tp.y = level.mapa.chao_em(tp.x, tp.y + 1.0)
			Proj.criar(get_parent(), "turret", tp, {"vida": 8.0, "cor": Color("ffb347"), "mult": dmg_mult()})

func _skill2() -> void:
	match chave:
		"bron":  # Aparar (parry)
			_cooldown("sk2")
			guarda_t = 0.7
			parry_t = 0.25
			Fx.popup(get_parent(), global_position, "GUARDA", Color("cfd8dc"), 32)
		"solys":  # Bênção de Solys
			_cooldown("sk2")
			Fx.ring(get_parent(), global_position, 6.0, Color("ffe89c"), 0.5)
			for k in Game.HEROES.keys():
				if Game.vivos[k]:
					Game.hp[k] = minf(Game.hp_max(k), Game.hp[k] + 30.0)
					Game.contam[k] = maxf(0.0, Game.contam[k] - 40.0)
			hp = Game.hp[chave]
			Fx.popup(get_parent(), global_position, "BÊNÇÃO +30 / PURIFICA", Color("ffe89c"), 36)
		"ziggs":  # Mina de Impacto Expansivo
			if superaq_t > 0.0: return
			_cooldown("sk2")
			pressao += 20.0
			var mp := global_position
			mp.y = level.mapa.chao_em(mp.x, mp.y + 1.0)
			Proj.criar(get_parent(), "mine", mp, {"vida": 25.0, "dano": 40.0 * dmg_mult(), "area": 3.0, "stun": 1.5, "cor": Color("ff5544")})

func _ult() -> void:
	match chave:
		"bron":  # Fúria do Gladiador
			_cooldown("ult")
			furia_t = 8.0
			Fx.ring(get_parent(), global_position, 4.0, Color("ff3b2f"), 0.5)
			Fx.popup(get_parent(), global_position, "FÚRIA DO GLADIADOR!", Color("ff5544"), 42)
		"solys":  # Expurgo da Chama Prateada
			_cooldown("ult")
			Fx.ring(get_parent(), global_position, 8.0, Color("ffd34d"), 0.6)
			Fx.ring(get_parent(), global_position, 7.0, Color("d0d0d0"), 0.8)
			var total := 0.0
			for e in _inimigos():
				var v: Vector3 = Fx.plano_xz(e.centro() - centro())
				if v.length() <= 8.0:
					var d := 60.0 * dmg_mult()
					e.receber_dano(d, v.normalized(), 4.0, 0.5)
					e.silencio_t = 4.0
					total += d
			var cura := minf(60.0, total * 0.2)
			for k in Game.HEROES.keys():
				if Game.vivos[k]:
					Game.hp[k] = minf(Game.hp_max(k), Game.hp[k] + cura)
					Game.contam[k] = 0.0
			hp = Game.hp[chave]
			Fx.popup(get_parent(), global_position, "EXPURGO DA CHAMA PRATEADA", Color("fff2b0"), 44)
		"ziggs":  # Injetor de Adrenalina Sintética
			if superaq_t > 0.0: return
			_cooldown("ult")
			level.buff_t = 6.0
			Fx.ring(get_parent(), global_position, 5.0, Color("7dff7d"), 0.4)
			Fx.popup(get_parent(), global_position, "ADRENALINA!", Color("7dff7d"), 40)

# ------------------------------------------------------------------ dano recebido
func receber_dano(d: float, contaminacao: float = 0.0, origem: Vector3 = Vector3.ZERO, ignora_guarda: bool = false) -> void:
	if invuln_t > 0.0 or not ativo and not ignora_guarda:
		return
	var final := d
	if guarda_t > 0.0 and not ignora_guarda:
		if parry_t > 0.0:
			Fx.popup(get_parent(), global_position, "PARRY!", Color("ffffff"), 44)
			Fx.ring(get_parent(), global_position, 3.5, Color("ffffff"), 0.3)
			for e in _inimigos():
				if Fx.plano_xz(e.centro() - centro()).length() < 3.5:
					e.receber_dano(25.0 * dmg_mult(), Fx.plano_xz(e.centro() - centro()).normalized(), 3.0, 2.0)
			invuln_t = 0.3
			return
		final *= 0.3
		contaminacao *= 0.3
	if Game.contam[chave] >= 80.0:
		final *= 1.25
	hp -= final
	Game.contam[chave] = minf(100.0, Game.contam[chave] + contaminacao)
	Game.hp[chave] = hp
	invuln_t = 0.25
	if furia_t <= 0.0 and final > 12.0:
		stun_t = 0.15
	Fx.popup(get_parent(), global_position, str(int(final)), Color("ff6666"), 40)
	if origem != Vector3.ZERO:
		var kx := signf(global_position.x - origem.x)
		if kx == 0.0:
			kx = -face
		velocity.x = kx * 7.0
		velocity.y = maxf(velocity.y, 6.0)
	if hp <= 0.0:
		hp = 0.0
		Game.hp[chave] = 0.0
		Game.vivos[chave] = false
		morreu.emit(chave)
