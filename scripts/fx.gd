class_name Fx
extends RefCounted
## Efeitos visuais simples (3D) e utilidades.

static func popup(parent: Node, pos: Vector3, texto: String, cor: Color = Color.WHITE, tam: int = 48) -> void:
	var l := Label3D.new()
	l.text = texto
	l.modulate = cor
	l.font_size = tam
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.01
	parent.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 2.4, 0.8)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.2, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(l.queue_free)

static func ring(parent: Node, pos: Vector3, raio: float, cor: Color, dur: float = 0.35) -> void:
	var m := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 1.0
	cil.bottom_radius = 1.0
	cil.height = 0.08
	m.mesh = cil
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(cor.r, cor.g, cor.b, 0.55)
	mat.emission_enabled = true
	mat.emission = cor
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	parent.add_child(m)
	m.global_position = Vector3(pos.x, pos.y + 1.0, 0.6)
	m.rotation_degrees = Vector3(90, 0, 0)
	m.scale = Vector3(0.1, 1, 0.1)
	var tw := m.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3(raio, 1, raio), dur)
	tw.tween_property(mat, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(m.queue_free)

static var _tex_corte: ImageTexture = null

static func _textura_corte() -> ImageTexture:
	if _tex_corte != null:
		return _tex_corte
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# crescente: círculo grande menos círculo deslocado
	for y in range(n):
		for x in range(n):
			var p := Vector2(x - n * 0.5, y - n * 0.5)
			var d1 := p.length()
			var d2 := (p - Vector2(-n * 0.16, 0)).length()
			if d1 < n * 0.48 and d2 > n * 0.40:
				var borda := minf(n * 0.48 - d1, d2 - n * 0.40) / 6.0
				var a := clampf(borda, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
	_tex_corte = ImageTexture.create_from_image(img)
	return _tex_corte

## Corte em arco (golpe corpo a corpo): crescente brilhante à frente do herói.
static func corte(parent: Node, pos: Vector3, face: float, raio: float, cor: Color, dur: float = 0.22, ang0: float = -70.0, ang1: float = 70.0) -> void:
	var sp := Sprite3D.new()
	sp.texture = _textura_corte()
	sp.pixel_size = 2.0 * raio / 128.0
	sp.shaded = false
	sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sp.modulate = Color(cor.r * 1.4, cor.g * 1.4, cor.b * 1.4, 0.95)
	sp.flip_h = face < 0.0
	sp.flip_v = ang0 > ang1
	parent.add_child(sp)
	sp.global_position = Vector3(pos.x + face * raio * 0.55, pos.y + 1.2, 0.8)
	sp.scale = Vector3(0.6, 0.6, 1.0)
	var tw := sp.create_tween()
	tw.set_parallel(true)
	tw.tween_property(sp, "scale", Vector3(1.15, 1.15, 1.0), dur)
	tw.tween_property(sp, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(sp.queue_free)

static func faiscas(parent: Node, pos: Vector3, cor: Color, qtd: int = 10) -> void:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -9, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = cor
	p.process_material = pm
	var q := SphereMesh.new()
	q.radius = 0.07
	q.height = 0.14
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.emission_enabled = true
	mat.emission = cor
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = mat
	p.draw_pass_1 = q
	p.amount = qtd
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	parent.add_child(p)
	p.global_position = pos + Vector3(0, 1.0, 0)
	p.emitting = true
	p.get_tree().create_timer(1.2).timeout.connect(p.queue_free)

## Plano de jogo (side-scroller): mantém x e y, descarta z.
static func plano_xz(v: Vector3) -> Vector3:
	return Vector3(v.x, v.y, 0)
