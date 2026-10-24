class_name Proj
extends Node3D
## Projéteis, torretas, minas e zonas de dano (side-scroller 2.5D). Tipos: shard, blood, bolt, turret, mine, zone, pira.

var kind := "shard"
var vel := Vector3.ZERO
var dano := 10.0
var vida := 2.0
var raio := 0.6
var contam := 0.0
var cor := Color.WHITE
var dono_heroi := true
var t := 0.0
var tick := 0.0
var extra := {}
var mapa: Mapa = null

static func criar(pai: Node, tipo: String, pos: Vector3, p: Dictionary) -> Proj:
	var pr := Proj.new()
	pr.process_mode = Node.PROCESS_MODE_PAUSABLE
	pr.kind = tipo
	pr.vel = p.get("vel", Vector3.ZERO)
	pr.dano = p.get("dano", 10.0)
	pr.vida = p.get("vida", 2.0)
	pr.raio = p.get("raio", 0.6)
	pr.contam = p.get("contam", 0.0)
	pr.cor = p.get("cor", Color.WHITE)
	pr.dono_heroi = p.get("heroi", true)
	pr.extra = p
	pai.add_child(pr)
	pr.global_position = Vector3(pos.x, pos.y, 0.5)
	var w = pai.get_tree().get_first_node_in_group("mundo")
	if w != null:
		pr.mapa = w.mapa
	pr._visual()
	return pr

func centro() -> Vector3:
	if kind in ["turret", "mine", "zone", "pira"]:
		return global_position + Vector3(0, 0.5, 0)
	return global_position

func _visual() -> void:
	var m := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.emission_enabled = true
	mat.emission = cor
	mat.emission_energy_multiplier = 1.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match kind:
		"turret":
			var b := BoxMesh.new()
			b.size = Vector3(0.7, 1.0, 0.7)
			m.mesh = b
			mat.albedo_color = Color("8a6a2a")
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			m.position.y = 0.5
		"mine":
			var c := CylinderMesh.new()
			c.top_radius = 0.4
			c.bottom_radius = 0.4
			c.height = 0.25
			m.mesh = c
			m.position.y = 0.12
		"zone":
			var b2 := BoxMesh.new()
			b2.size = Vector3(raio * 2.0, 1.0, 0.6)
			m.mesh = b2
			mat.albedo_color = Color(cor.r, cor.g, cor.b, 0.35)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.position.y = 0.5
		_:
			var s := SphereMesh.new()
			s.radius = 0.22 if kind != "blood" else 0.3
			s.height = s.radius * 2.0
			m.mesh = s
	m.material_override = mat
	add_child(m)
	if kind in ["blood", "shard", "bolt"]:
		var luz := OmniLight3D.new()
		luz.light_color = cor
		luz.omni_range = 3.0
		luz.light_energy = 1.2
		add_child(luz)

func _physics_process(delta: float) -> void:
	t += delta
	vida -= delta
	match kind:
		"shard", "blood", "bolt":
			global_position += vel * delta
			if mapa != null and mapa.solido_em(global_position):
				Fx.faiscas(get_parent(), global_position - Vector3(0, 1.0, 0), cor, 4)
				queue_free()
				return
			if _colide():
				queue_free()
		"turret":
			tick -= delta
			if tick <= 0.0:
				tick = 0.5
				var alvo := _inimigo_mais_perto(12.0)
				if alvo != null:
					var d: Vector3 = Fx.plano_xz(alvo.centro() - centro()).normalized()
					Proj.criar(get_parent(), "shard", centro(), {"vel": d * 15.0, "dano": 8.0 * extra.get("mult", 1.0), "vida": 1.2, "cor": Color("ffb347"), "heroi": true})
		"mine":
			if t > 0.6:
				for e in get_tree().get_nodes_in_group("enemies"):
					if Fx.plano_xz(e.centro() - centro()).length() < 1.8:
						_explodir()
						return
		"zone":
			tick -= delta
			if tick <= 0.0:
				tick = 0.5
				_dano_area(centro(), raio, dano, 0.0, 0.0, 0.0)
	if vida <= 0.0:
		queue_free()

func _colide() -> bool:
	if dono_heroi:
		for e in get_tree().get_nodes_in_group("enemies"):
			var v: Vector3 = Fx.plano_xz(e.centro() - global_position)
			if absf(v.x) < raio + e.meia + 0.2 and absf(v.y) < raio + e.alt * 0.5:
				e.receber_dano(dano, Vector3(signf(vel.x), 0, 0), 2.0, 0.15)
				Fx.faiscas(get_parent(), global_position - Vector3(0, 1.0, 0), cor, 5)
				return true
	else:
		for h in get_tree().get_nodes_in_group("player"):
			var v2: Vector3 = Fx.plano_xz(h.centro() - global_position)
			if absf(v2.x) < raio + h.meia + 0.1 and absf(v2.y) < raio + h.alt * 0.5:
				h.receber_dano(dano, contam, global_position)
				return true
	return false

func _inimigo_mais_perto(alcance: float) -> Node3D:
	var melhor: Node3D = null
	var md := alcance
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := Fx.plano_xz(e.centro() - centro()).length()
		if d < md:
			md = d
			melhor = e
	return melhor

func _explodir() -> void:
	Fx.ring(get_parent(), global_position, extra.get("area", 3.0), cor)
	_dano_area(centro(), extra.get("area", 3.0), dano, 6.0, extra.get("stun", 1.5), 0.0)
	queue_free()

func _dano_area(c: Vector3, r: float, d: float, kb: float, stun: float, _x: float) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		var v: Vector3 = Fx.plano_xz(e.centro() - c)
		if v.length() <= r + e.meia:
			e.receber_dano(d, v.normalized(), kb, stun)

func explodir_em(atraso: float, area: float, d: float) -> void:
	## Usado pela Pira de Julgamento: após 'atraso' explode e deixa uma zona de fogo.
	var tw := create_tween()
	tw.tween_interval(atraso)
	tw.tween_callback(func():
		Fx.ring(get_parent(), global_position, area, Color("ffd34d"), 0.4)
		Fx.faiscas(get_parent(), global_position - Vector3(0, 1.0, 0), Color("ffd34d"), 24)
		_dano_area(centro(), area, d, 5.0, 0.4, 0.0)
		kind = "zone"
		raio = area
		dano = 8.0
		vida = 4.0
		tick = 0.5
		_visual())
