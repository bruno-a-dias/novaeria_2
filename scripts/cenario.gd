class_name Cenario
extends Node3D
## Constrói a cena 3D (HD-2D) a partir do Mapa: terreno em blocos mesclados, fundos por setor,
## decoração temática, luzes, portões e espinhos.

const PROF := 5.0                 # profundidade do terreno (z de -5 a 0)
const Z_FUNDO := -5.05

var mapa: Mapa
var luzes: Array = []             # {luz, x, y, base}
var portao_vis := {}              # id -> MeshInstance3D
var _mats := {}
var _tex_rocha: Texture2D
var _rng := RandomNumberGenerator.new()

func construir(m: Mapa) -> void:
	mapa = m
	_rng.seed = 4242
	_tex_rocha = _gerar_textura()
	_terreno()
	_fundos()
	for s in mapa.salas:
		_decorar(s)
	_fechar_lotes()
	_espinhos()
	_portoes()
	for b in mapa.bancos:
		_fogueira(b)

func _gerar_textura() -> Texture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.07
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n.seed = 7
	var img := n.get_image(128, 128, false, false, false)
	img.convert(Image.FORMAT_RGB8)
	# clareia para servir de multiplicador suave
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			var v := 0.62 + c.r * 0.38
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _mat(cor: Color, rocha: bool = false, emissivo: bool = false, alfa: float = 1.0, rug: float = 0.9) -> StandardMaterial3D:
	var chave := "%s_%s_%s_%s" % [cor.to_html(true), rocha, emissivo, alfa]
	if _mats.has(chave):
		return _mats[chave]
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = rug
	if rocha:
		m.albedo_texture = _tex_rocha
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.14, 0.14, 0.14)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if emissivo:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alfa < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(cor.r, cor.g, cor.b, alfa)
	_mats[chave] = m
	return m

## Caixas estáticas são acumuladas por material e fundidas em UMA malha (o Compatibility/web falha
## ao passar de ~1000 MeshInstance3D na cena).
var _lotes := {}      # Material -> SurfaceTool

func _caixa_lote(pos: Vector3, tam: Vector3, mat: Material) -> void:
	if not _lotes.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_lotes[mat] = st
	var bm := BoxMesh.new()
	bm.size = tam
	(_lotes[mat] as SurfaceTool).append_from(bm, 0, Transform3D(Basis.IDENTITY, pos))

func _fechar_lotes() -> void:
	for mat in _lotes.keys():
		var mi := MeshInstance3D.new()
		mi.mesh = (_lotes[mat] as SurfaceTool).commit()
		mi.material_override = mat
		add_child(mi)
	_lotes.clear()

func _caixa(pos: Vector3, tam: Vector3, mat: Material, pai: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = mat
	(pai if pai != null else self).add_child(mi)
	mi.position = pos
	return mi

func _cil(pos: Vector3, raio: float, alt: float, mat: Material, raio_topo: float = -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = raio
	cm.top_radius = raio if raio_topo < 0.0 else raio_topo
	cm.height = alt
	cm.radial_segments = 10
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	add_child(mi)
	mi.position = pos
	return mi

func _esfera(pos: Vector3, raio: float, mat: Material, esc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = raio
	sm.height = raio * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	add_child(mi)
	mi.position = pos
	mi.scale = esc
	return mi

func _luz(pos: Vector3, cor: Color, energia: float, alcance: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = cor
	l.light_energy = energia
	l.omni_range = alcance
	l.omni_attenuation = 1.3
	add_child(l)
	l.position = pos
	luzes.append({"luz": l, "x": pos.x, "y": pos.y, "base": energia})
	return l

# ------------------------------------------------------------------ terreno
func _terreno() -> void:
	var ativos := {}
	var topo_runs: Array = []
	for y in range(Mapa.H):
		var runs: Array = []
		var x := 0
		while x < Mapa.W:
			if mapa.g[y * Mapa.W + x] == 1:
				var st := mapa.setor_de(x + 0.5, y + 0.5)
				var x0 := x
				while x + 1 < Mapa.W and mapa.g[y * Mapa.W + x + 1] == 1 and mapa.setor_de(x + 1.5, y + 0.5) == st:
					x += 1
				runs.append([x0, x, st])
			x += 1
		var novos := {}
		for r in runs:
			var key := "%d,%d,%s" % [r[0], r[1], r[2]]
			if ativos.has(key):
				novos[key] = ativos[key]
				ativos.erase(key)
			else:
				novos[key] = y
		for key in ativos.keys():
			_bloco(key, ativos[key], y - 1)
		ativos = novos
		# faixas de topo (superfícies expostas)
		var tx := 0
		while tx < Mapa.W:
			if mapa.g[y * Mapa.W + tx] == 1 and mapa.tile(tx, y + 1) != 1:
				var st2 := mapa.setor_de(tx + 0.5, y + 0.5)
				var t0 := tx
				while tx + 1 < Mapa.W and mapa.g[y * Mapa.W + tx + 1] == 1 and mapa.tile(tx + 1, y + 1) != 1 and mapa.setor_de(tx + 1.5, y + 0.5) == st2:
					tx += 1
				topo_runs.append([t0, tx, y, st2])
			tx += 1
	for key in ativos.keys():
		_bloco(key, ativos[key], Mapa.H - 1)
	for r in topo_runs:
		var cor: Color = Game.SETORES[r[3]]["topo"]
		var w: float = r[1] - r[0] + 1.0
		_caixa_lote(Vector3(r[0] + w * 0.5, r[2] + 1.0 - 0.14, -1.75), Vector3(w, 0.3, 6.5), _mat(cor, true))
	_plataformas()

## Plataformas de atravessar por baixo (células 2): laje fina com borda clara, agrupadas por linha e setor.
## Usa MultiMesh (uma chamada de desenho por setor e parte) para não inflar a cena.
func _plataformas() -> void:
	var grupos := {}      # "setor|parte" -> Array[Transform3D]
	for y in range(Mapa.H):
		var x := 0
		while x < Mapa.W:
			if mapa.g[y * Mapa.W + x] == 2:
				var st := mapa.setor_de(x + 0.5, y + 0.5)
				var x0 := x
				while x + 1 < Mapa.W and mapa.g[y * Mapa.W + x + 1] == 2 and mapa.setor_de(x + 1.5, y + 0.5) == st:
					x += 1
				var w := float(x - x0 + 1)
				var cx := x0 + w * 0.5
				_grupo_add(grupos, st + "|topo", Vector3(cx, y + 0.82, -1.0), Vector3(w, 0.36, 3.2))
			x += 1
	for chave in grupos.keys():
		var partes: PackedStringArray = chave.split("|")
		var cfg: Dictionary = Game.SETORES[partes[0]]
		var rocha: Color = cfg["rocha"]
		var cor: Color
		match partes[1]:
			"corpo": cor = Color(rocha.r * 1.15, rocha.g * 1.15, rocha.b * 1.15)
			"topo": cor = cfg["topo"]
			_: cor = Color(rocha.r * 0.6, rocha.g * 0.6, rocha.b * 0.6)
		var mp := _mat(cor, true)
		for tr in grupos[chave]:
			_caixa_lote(tr.origin, tr.basis.get_scale(), mp)
	_fechar_lotes()

func _grupo_add(grupos: Dictionary, chave: String, pos: Vector3, tam: Vector3) -> void:
	if not grupos.has(chave):
		grupos[chave] = []
	grupos[chave].append(Transform3D(Basis.from_scale(tam), pos))

func _bloco(key: String, y0: int, y1: int) -> void:
	var p := key.split(",")
	var x0 := int(p[0])
	var x1 := int(p[1])
	var st: String = p[2]
	var w := x1 - x0 + 1.0
	var h := y1 - y0 + 1.0
	var cor: Color = Game.SETORES[st]["rocha"]
	var v := 0.9 + 0.1 * float((x0 * 7 + y0 * 13) % 3) / 2.0
	_caixa_lote(Vector3(x0 + w * 0.5, y0 + h * 0.5, -PROF * 0.5), Vector3(w, h, PROF), _mat(Color(cor.r * v, cor.g * v, cor.b * v), true))

## Arte de fundo por setor (planos pintados de referência). Cada imagem já vem espelhada em 2x2,
## então repetir a textura continua sem emendas, o que permite "expandir" o fundo por todo o setor.
const FUNDO_ARTE := {
	# setor: [arquivo, brilho, y do chão principal (tiles), posição do chão na imagem (0 topo .. 1 base)]
	"estalagem": ["estalagem", 0.85, 90.0, 0.72],
	"floresta": ["floresta", 0.85, 90.0, 0.78],
	"kaldrak": ["kaldrak", 0.85, 117.0, 0.72],
	"marcha": ["marcha", 0.85, 76.0, 0.72],
	"cripta": ["cripta", 0.85, 118.0, 0.72],
	"altar": ["altar", 0.85, 126.0, 0.72],
	"subterraneo": ["subterraneo", 0.9, 8.0, 0.72],
	"confluencia": ["confluencia", 1.25, 40.0, 0.72, 46.0],     # usa a arte "confluencia.jpg" se existir; senão, cai nos túneis
}
const FUNDO_ALTURA := 18.0        # altura em tiles de uma cópia da imagem

func _fundos() -> void:
	var i := 0
	for r in Mapa.SETOR_RECTS:
		var cor: Color = Game.SETORES[r[0]]["rocha"]
		var x0: float = r[1]
		var y0: float = r[2]
		var x1: float = r[3]
		var y1: float = r[4]
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(x1 - x0, y1 - y0)
		q.mesh = qm
		var mat: StandardMaterial3D
		if FUNDO_ARTE.has(r[0]):
			var cfg: Array = FUNDO_ARTE[r[0]]
			var arq: String = cfg[0]
			if not ResourceLoader.exists("res://assets/fundos/%s.jpg" % arq):
				arq = "subterraneo"
			var tex: Texture2D = load("res://assets/fundos/%s.jpg" % arq)
			mat = StandardMaterial3D.new()
			mat.albedo_texture = tex
			var br: float = cfg[1]
			mat.albedo_color = Color(br, br, br)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.texture_repeat = true
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			var asp: float = float(tex.get_width()) / float(tex.get_height())   # proporção do bloco 2x2 (= da imagem)
			var alt_img: float = float(cfg[4]) if cfg.size() > 4 else FUNDO_ALTURA   # altura em tiles de uma cópia
			var larg := alt_img * 2.0 * asp               # largura em tiles do bloco 2x2
			var alt2 := alt_img * 2.0
			var chao_y: float = float(r[5]) if r.size() > 5 else float(cfg[2])
			var topo_img: float = chao_y + float(cfg[3]) * alt_img   # y do topo da imagem para o chão alinhar
			mat.uv1_scale = Vector3((x1 - x0) / larg, (y1 - y0) / alt2, 1.0)
			mat.uv1_offset = Vector3(fposmod(x0, larg) / larg, fposmod(topo_img - y1, alt2) / alt2, 0.0)
		else:
			mat = _mat(Color(cor.r * 0.55, cor.g * 0.55, cor.b * 0.55), true)
		q.material_override = mat
		add_child(q)
		q.position = Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, Z_FUNDO - 0.01 * i)
		i += 1

## Estalagem do Cervo Prateado, refeita do zero: poucas peças simples (vigas, lareira, balcão, mesas, barris, lanternas).
func _taverna(x0: int, x1: int, y0: int, y1: int, salao: bool) -> void:
	var madeira := _mat(Color("5a3a20"), true)
	var escura := _mat(Color("3a2414"), true)
	var chao := float(y0)
	# vigas de teto e pilares
	_vigas(x0, x1, y0, y1)
	for xx in range(x0 + 6, x1 - 2, 9):
		_caixa_lote(Vector3(xx, chao + (y1 - y0) * 0.5, -3.2), Vector3(0.7, y1 - y0, 0.7), escura)
	# lanternas penduradas (luz quente)
	for xx in range(x0 + 5, x1 - 3, 8):
		_caixa_lote(Vector3(xx, y1 - 1.5, -2.0), Vector3(0.06, 3.0, 0.06), escura)
		_caixa_lote(Vector3(xx, y1 - 3.1, -2.0), Vector3(0.5, 0.6, 0.5), _mat(Color("ffcc77"), false, true))
		_luz(Vector3(xx, y1 - 3.1, -1.5), Color("ffae5a"), 1.5, 9.0)
	if salao:
		# brilho da lareira (a lareira em si vem da arte de fundo)
		_luz(Vector3(x0 + 3.0, chao + 1.6, -2.0), Color("ff8a3a"), 2.4, 12.0)
		# balcão do bar com banquetas e prateleira
		_caixa_lote(Vector3(x0 + 20.0, chao + 0.55, -2.6), Vector3(9.0, 1.1, 1.3), madeira)
		_caixa_lote(Vector3(x0 + 20.0, chao + 1.15, -2.6), Vector3(9.4, 0.18, 1.5), escura)
		_caixa_lote(Vector3(x0 + 20.0, chao + 3.0, -3.6), Vector3(8.0, 0.2, 0.6), madeira)
		for i in range(5):
			_cil(Vector3(x0 + 16.5 + i * 1.75, chao + 0.4, -1.2), 0.32, 0.8, madeira)
		# mesas com banquinhos no térreo (lado leste)
		for mx in [x0 + 28.0, x0 + 32.0]:
			_caixa_lote(Vector3(mx, chao + 0.6, -1.6), Vector3(2.2, 0.16, 1.1), madeira)
			_caixa_lote(Vector3(mx, chao + 0.3, -1.6), Vector3(0.18, 0.6, 0.18), escura)
	else:
		# pátio: muro baixo, barris e caixotes
		_caixa_lote(Vector3((x0 + x1) * 0.5, chao + 0.9, -3.6), Vector3(x1 - x0 - 1, 1.8, 0.6), _mat(Color("4a4440"), true))
		for i in range(3):
			var bx := x0 + 3.0 + i * 5.0
			_caixa_lote(Vector3(bx, chao + 0.5, -2.0), Vector3(1.0, 1.0, 1.0), madeira)
	# barris
	for i in range(maxi(1, (x1 - x0) / 12)):
		var bx2 := _rng.randf_range(x0 + 2, x1 - 2)
		_cil(Vector3(bx2, chao + 0.55, -2.2), 0.5, 1.1, madeira)

# ------------------------------------------------------------------ decoração
func _decorar(s: Dictionary) -> void:
	var cfg: Dictionary = Game.SETORES[s["setor"]]
	var luz_cor: Color = cfg["luz"]
	var x0: int = s["x0"]
	var x1: int = s["x1"]
	var y0: int = s["y0"]
	var y1: int = s["y1"]
	var largura := x1 - x0
	match s["deco"]:
		"taverna":
			_taverna(x0, x1, y0, y1, true)
		"taverna_patio":
			_taverna(x0, x1, y0, y1, false)
		"cabana":
			_tochas(x0 + 3, x1 - 2, y0, 4.5, Color("ffc070"), 1.5)
			_caixa(Vector3((x0 + x1) * 0.5, y0 + 0.45, -2.0), Vector3(3.2, 0.9, 1.4), _mat(Color("4a3020")))
			_caixa(Vector3(x0 + 4.5, y0 + 4.2, -4.8), Vector3(2.2, 1.5, 0.08), _mat(Color("9a8a58")))
			_luz(Vector3((x0 + x1) * 0.5, y0 + 2.5, -1.5), Color("ffb060"), 1.6, 9.0)
		"floresta":
			_arvores(x0, x1, y0, y1)
			for xx in range(x0 + 6, x1, 14):
				_luz(Vector3(xx, y0 + 6.0 + _rng.randf() * 3.0, -2.0), Color("8affc8"), 1.1, 11.0)
			_raios_de_luz(x0, x1, y0, y1)
		"tuneis":
			_canos(x0, x1, y1)
			_tochas(x0 + 6, x1 - 4, y0, 4.0, Color("6ac8ff"), 1.5)
			for xx in range(x0 + 10, x1 - 5, 12):
				_arco(xx, y0, y1)
		"confluencia":
			_cristais(x0, x1, y0, y1, Color("5ad0ff"))
			_tochas(x0 + 8, x1 - 6, y0, 4.0, Color("6ac8ff"), 1.4)
			for xx in range(x0 + 14, x1 - 8, 22):
				_luz(Vector3(xx, y0 + 12.0, -2.0), Color("5ad0ff"), 1.3, 14.0)
		"ruinas":
			_pilares_quebrados(x0, x1, y0, y1)
			for xx in range(x0 + 4, x1, 9):
				_braseiro(xx, mapa.chao_em(xx, y0 + 2), Color("ff8a3a"))
		"altar_besta":
			_sigilo(Vector3((x0 + x1) * 0.5, y0 + 6.0, Z_FUNDO + 0.04), 5.5, Color("c01818"))
			for xx in [x0 + 2, x1 - 2]:
				_braseiro(xx, y0, Color("ff5a3a"))
			_correntes(x0, x1, y1)
		"marcha":
			_cristais(x0, x1, y0, y1, Color("b36aff"))
			_tochas(x0 + 4, x1 - 3, y0, 4.5, Color("b36aff"), 1.5)
		"marcha_portoes":
			_cristais(x0, x1, y0, y1, Color("b36aff"))
			_portal(x0, x1, y0)
		"poco":
			_cristais(x0, x1, y0, y1, Color("8a5aff"))
			_correntes(x0, x1, y1)
			for yy in range(y0 + 8, y1 - 4, 12):
				_luz(Vector3((x0 + x1) * 0.5, yy, -1.5), Color("b36aff"), 1.2, 12.0)
		"cripta":
			_colunas(x0, x1, y0, y1, Color("ff3b3b"))
		"salao_ritual":
			_sigilo(Vector3((x0 + x1) * 0.5, y0 + 8.0, Z_FUNDO + 0.04), 7.5, Color("ff2a2a"))
			_colunas(x0, x1, y0, y1, Color("ff3b3b"))
			_estandartes(x0, x1, y0, y1)
		"escadaria":
			_colunas(x0, x1, y0 + 6, y1, Color("ff4a6a"))
			_estandartes(x0, x1, y0 + 6, y1)
		"altar":
			_sigilo(Vector3((x0 + x1) * 0.5, y0 + 10.0, Z_FUNDO + 0.04), 9.0, Color("ff4ad8"))
			_colunas(x0, x1, y0, y1, Color("ff4ad8"))
			_rosas(x0, x1, y0)
		_:
			_tochas(x0 + 4, x1 - 3, y0, 4.5, luz_cor, 1.4)

func _tochas(xa: int, xb: int, y_base: int, altura: float, cor: Color, energia: float) -> void:
	var xx := xa
	while xx <= xb:
		var y := mapa.chao_em(xx, y_base + 2) + altura
		_caixa(Vector3(xx, y - 0.3, -4.85), Vector3(0.25, 0.7, 0.2), _mat(Color("2a2420")))
		_esfera(Vector3(xx, y + 0.25, -4.8), 0.22, _mat(cor, false, true), Vector3(1, 1.5, 1))
		_luz(Vector3(xx, y + 0.5, -3.4), cor, energia, 10.0)
		xx += 11

func _janelas(x0: int, x1: int, y0: int, y1: int) -> void:
	var vidro := _mat(Color("8ab4ff"), false, true, 0.55)
	var moldura := _mat(Color("2a1a10"))
	for xx in range(x0 + 12, x1 - 4, 15):
		var y := mapa.chao_em(xx, y0 + 2) + 6.5
		_caixa(Vector3(xx, y, -4.95), Vector3(2.4, 3.4, 0.12), moldura)
		_caixa(Vector3(xx, y, -4.88), Vector3(2.0, 3.0, 0.05), vidro)
		_caixa(Vector3(xx, y, -4.84), Vector3(0.12, 3.0, 0.05), moldura)
		_luz(Vector3(xx, y - 1.0, -3.0), Color("8ab4ff"), 0.8, 9.0)

func _braseiro(x: float, y: float, cor: Color) -> void:
	_cil(Vector3(x, y + 0.5, -2.4), 0.45, 1.0, _mat(Color("2a2a30")), 0.6)
	_esfera(Vector3(x, y + 1.25, -2.4), 0.38, _mat(cor, false, true), Vector3(1, 1.6, 1))
	_luz(Vector3(x, y + 2.0, -1.4), cor, 1.6, 10.0)

func _vigas(x0: int, x1: int, y0: int, y1: int) -> void:
	var madeira := _mat(Color("3a2616"))
	_caixa(Vector3((x0 + x1) * 0.5 + 0.5, y1 + 0.55, -2.5), Vector3(x1 - x0 + 1.0, 0.6, 0.6), madeira)
	for xx in range(x0 + 2, x1, 8):
		_caixa(Vector3(xx, (y0 + y1) * 0.5 + 0.5, -4.0), Vector3(0.6, y1 - y0 + 1.0, 0.6), madeira)

func _arvores(x0: int, x1: int, y0: int, y1: int) -> void:
	var tronco := _mat(Color("2a1c12"))
	var copa := _mat(Color("183a22"))
	var copa2 := _mat(Color("245230"))
	var xx := float(x0 + 2)
	while xx < x1 - 1:
		var z := -_rng.randf_range(2.4, 4.4)
		var chao := mapa.chao_em(xx, y0 + 3)
		var alt := _rng.randf_range(9.0, 15.0)
		_cil(Vector3(xx, chao + alt * 0.5, z), 0.55, alt, tronco, 0.8)
		_esfera(Vector3(xx, chao + alt, z), 3.4, copa, Vector3(1.2, 0.7, 0.8))
		_esfera(Vector3(xx + 2.0, chao + alt - 1.2, z + 0.3), 2.4, copa2, Vector3(1.1, 0.7, 0.8))
		_esfera(Vector3(xx - 2.2, chao + alt - 1.4, z - 0.3), 2.2, copa, Vector3(1.1, 0.7, 0.8))
		xx += _rng.randf_range(6.0, 9.0)

func _raios_de_luz(x0: int, x1: int, _y0: int, y1: int) -> void:
	var m := _mat(Color("c8ffd8"), false, true, 0.07)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for xx in range(x0 + 8, x1 - 4, 17):
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(3.0, float(y1 - 22) + 6.0)
		q.mesh = qm
		q.material_override = m
		add_child(q)
		q.position = Vector3(xx, y1 - 10.0, -3.8)
		q.rotation_degrees.z = -14

func _canos(x0: int, x1: int, y1: int) -> void:
	var cano := _mat(Color("4a3a2e"), false, false, 1.0, 0.5)
	cano.metallic = 0.6
	var c := _cil(Vector3((x0 + x1) * 0.5 + 0.5, y1 - 0.3, -3.5), 0.35, x1 - x0 + 1.0, cano)
	c.rotation_degrees.z = 90

func _arco(x: int, y0: int, y1: int) -> void:
	var m := _mat(Color("2e2a26"))
	_caixa(Vector3(x, (y0 + y1) * 0.5, -4.2), Vector3(0.7, y1 - y0 + 1.0, 0.7), m)
	_caixa(Vector3(x + 4, (y0 + y1) * 0.5, -4.2), Vector3(0.7, y1 - y0 + 1.0, 0.7), m)
	_caixa(Vector3(x + 2, y1 + 0.2, -4.2), Vector3(5.0, 0.7, 0.7), m)

func _pilares_quebrados(x0: int, x1: int, y0: int, y1: int) -> void:
	var m := _mat(Color("6a6878"), true)
	var xx := float(x0 + 3)
	while xx < x1 - 2:
		var alt := _rng.randf_range(5.0, float(y1 - y0))
		var chao := mapa.chao_em(xx, y0 + 2)
		_caixa(Vector3(xx, chao + alt * 0.5, -_rng.randf_range(2.6, 4.2)), Vector3(1.3, alt, 1.3), m)
		xx += _rng.randf_range(7.0, 11.0)

func _correntes(x0: int, x1: int, y1: int) -> void:
	var m := _mat(Color("3a3a42"), false, false, 1.0, 0.4)
	for xx in range(x0 + 3, x1 - 1, 6):
		var l := _rng.randf_range(3.0, 7.0)
		_cil(Vector3(xx, y1 + 1.0 - l * 0.5, -3.0), 0.07, l, m)

func _cristais(x0: int, x1: int, y0: int, y1: int, cor: Color) -> void:
	var m := _mat(cor, false, true, 0.85)
	for i in range(maxi(2, (x1 - x0) / 5)):
		var xx := _rng.randf_range(x0 + 1, x1 - 1)
		var yy := _rng.randf_range(y0 + 1, y1 - 2)
		var c := _cil(Vector3(xx, yy, -4.5), 0.35, 1.6, m, 0.0)
		c.rotation_degrees.z = _rng.randf_range(-35, 35)

func _portal(x0: int, x1: int, y0: int) -> void:
	# Portões da Cripta ao fundo: arco monumental com runas rubras
	var pedra := _mat(Color("2a2030"), true)
	var runa := _mat(Color("ff2a3a"), false, true)
	var cx := x0 + 3.5
	_caixa(Vector3(cx - 3.2, y0 + 7.0, -4.5), Vector3(1.6, 14.0, 1.2), pedra)
	_caixa(Vector3(cx + 3.2, y0 + 7.0, -4.5), Vector3(1.6, 14.0, 1.2), pedra)
	_caixa(Vector3(cx, y0 + 14.2, -4.5), Vector3(8.0, 1.6, 1.2), pedra)
	_esfera(Vector3(cx, y0 + 14.2, -3.8), 0.7, runa)
	_luz(Vector3(cx, y0 + 8.0, -2.0), Color("ff3a3a"), 1.6, 14.0)

func _colunas(x0: int, x1: int, y0: int, y1: int, cor: Color) -> void:
	var m := _mat(Color("3a1c24"), true)
	var glow := _mat(cor, false, true)
	var xx := x0 + 3
	while xx < x1:
		var chao := mapa.chao_em(xx, y0 + 2)
		var topo := float(y1) + 0.5
		_caixa(Vector3(xx, (chao + topo) * 0.5, -4.0), Vector3(1.4, topo - chao, 1.4), m)
		_caixa(Vector3(xx, chao + 4.0, -3.25), Vector3(0.14, 3.2, 0.14), glow)
		_luz(Vector3(xx, chao + 5.0, -2.2), cor, 1.3, 11.0)
		xx += 9

func _estandartes(x0: int, x1: int, y0: int, y1: int) -> void:
	var m := _mat(Color("7a0f1f"), false, false, 1.0)
	for xx in range(x0 + 7, x1 - 2, 9):
		var chao := mapa.chao_em(xx, y0 + 2)
		_caixa(Vector3(xx, y1 - 3.5, -4.7), Vector3(1.8, 6.0, 0.08), m)
		_caixa(Vector3(xx, y1 - 3.5, -4.64), Vector3(0.18, 5.0, 0.04), _mat(Color("e0b84a"), false, true))
		if chao > y0:
			pass

func _sigilo(pos: Vector3, raio: float, cor: Color) -> void:
	var m := _mat(cor, false, true, 0.55)
	var anel := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = raio * 0.92
	tm.outer_radius = raio
	tm.rings = 32
	tm.ring_segments = 6
	anel.mesh = tm
	anel.material_override = m
	add_child(anel)
	anel.position = pos
	anel.rotation_degrees.x = 90
	var anel2 := MeshInstance3D.new()
	var tm2 := TorusMesh.new()
	tm2.inner_radius = raio * 0.55
	tm2.outer_radius = raio * 0.6
	tm2.rings = 28
	tm2.ring_segments = 6
	anel2.mesh = tm2
	anel2.material_override = m
	add_child(anel2)
	anel2.position = pos
	anel2.rotation_degrees.x = 90
	# estrela de 5 pontas (linhas finas)
	for i in range(5):
		var a := TAU * i / 5.0 + PI * 0.5
		var b := TAU * ((i + 2) % 5) / 5.0 + PI * 0.5
		var pa := Vector2(cos(a), sin(a)) * raio * 0.58
		var pb := Vector2(cos(b), sin(b)) * raio * 0.58
		var meio := (pa + pb) * 0.5
		var compr := pa.distance_to(pb)
		var seg := _caixa(pos + Vector3(meio.x, meio.y, 0), Vector3(compr, 0.1, 0.03), m)
		seg.rotation.z = (pb - pa).angle()
	_luz(pos + Vector3(0, 0, 2.5), cor, 1.2, raio * 2.4)

func _rosas(x0: int, x1: int, y0: int) -> void:
	var talo := _mat(Color("2a0f2a"))
	var flor := _mat(Color("5a1a4a"), false, true)
	for xx in range(x0 + 3, x1 - 1, 5):
		var h := _rng.randf_range(3.0, 7.0)
		_cil(Vector3(xx, y0 + h * 0.5, -3.0), 0.08, h, talo)
		_esfera(Vector3(xx, y0 + h, -3.0), 0.3, flor)

func _fogueira(b: Dictionary) -> void:
	var x: float = b["x"] + 0.5
	var y: float = b["y"]
	var tora := _mat(Color("3a2414"))
	var l1 := _cil(Vector3(x, y + 0.18, -0.2), 0.14, 1.3, tora)
	l1.rotation_degrees.z = 70
	var l2 := _cil(Vector3(x, y + 0.18, -0.2), 0.14, 1.3, tora)
	l2.rotation_degrees.z = -70
	var chama := _esfera(Vector3(x, y + 0.75, -0.2), 0.3, _mat(Color("ffb050"), false, true), Vector3(0.9, 1.7, 0.9))
	chama.name = "Chama_" + b["id"]
	_luz(Vector3(x, y + 1.4, 0.8), Color("ffa040"), 1.9, 11.0)

# ------------------------------------------------------------------ espinhos e portões
func _espinhos() -> void:
	var m := _mat(Color("9a8a96"), false, false, 1.0, 0.35)
	m.metallic = 0.7
	for y in range(Mapa.H):
		for x in range(Mapa.W):
			if mapa.g[y * Mapa.W + x] == 3:
				for k in range(3):
					_cil(Vector3(x + 0.2 + k * 0.3, y + 0.45, -0.1 + (k % 2) * 0.2), 0.14, 0.9, m, 0.0)

func _portoes() -> void:
	for id in mapa.portoes.keys():
		var p: Dictionary = mapa.portoes[id]
		var w: float = p["x1"] - p["x0"] + 1.0
		var h: float = p["y1"] - p["y0"] + 1.0
		var mi: MeshInstance3D
		match id:
			"barreira":
				var mat := _mat(Color("7a1f1f"), false, true, 0.55)
				mi = _caixa(Vector3(p["x0"] + w * 0.5, p["y0"] + h * 0.5, -1.0), Vector3(w, h, 3.0), mat)
			"besta_chao":
				mi = _caixa(Vector3(p["x0"] + w * 0.5, p["y0"] + h * 0.5, -2.0), Vector3(w, h, 5.0), _mat(Game.SETORES["kaldrak"]["rocha"], true))
			"cripta":
				mi = _caixa(Vector3(p["x0"] + w * 0.5, p["y0"] + h * 0.5, -1.0), Vector3(w + 0.6, h, 2.0), _mat(Color("2a2030"), true))
				var runa := _caixa(Vector3(0, 0, 1.05), Vector3(0.3, h * 0.7, 0.06), _mat(Color("ff2a3a"), false, true), mi)
				runa.name = "Runa"
			_:
				var mat2 := _mat(Color("3a3a42"), false, false, 1.0, 0.4)
				mat2.metallic = 0.7
				mi = _caixa(Vector3(p["x0"] + w * 0.5, p["y0"] + h * 0.5, -0.5), Vector3(w, h, 1.0), mat2)
				for k in range(int(h)):
					_caixa(Vector3(0, -h * 0.5 + 0.5 + k, 0.55), Vector3(w + 0.1, 0.12, 0.12), _mat(Color("c02020"), false, true), mi)
		portao_vis[id] = mi
		mi.visible = p["fechado"]

func atualizar_portao(id: String, fechado: bool, animar: bool = true) -> void:
	var mi: MeshInstance3D = portao_vis.get(id)
	if mi == null:
		return
	if fechado:
		mi.visible = true
		mi.scale = Vector3.ONE
	elif mi.visible and animar:
		var tw := mi.create_tween()
		tw.tween_property(mi, "scale", Vector3(1, 0.02, 1), 0.5)
		tw.tween_callback(func(): mi.visible = false; mi.scale = Vector3.ONE)
	else:
		mi.visible = false

## Liga só as luzes perto da câmera e faz as chamas tremularem.
func atualizar(cam: Vector3, t: float) -> void:
	for d in luzes:
		var perto: bool = absf(d["x"] - cam.x) < 26.0 and absf(d["y"] - cam.y) < 18.0
		var l: OmniLight3D = d["luz"]
		l.visible = perto
		if perto:
			l.light_energy = d["base"] * (0.9 + 0.1 * sin(t * 9.0 + d["x"] * 1.7))
