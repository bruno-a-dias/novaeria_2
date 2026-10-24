class_name MiniMapa
extends Control
## Minimapa (canto da tela) e mapa completo (tela de pausa) com névoa de exploração, estilo metroidvania.

var mundo: Node = null
var tex: ImageTexture = null
var grande := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _desenhar_marcador(p: Vector2, cor: Color, tam: float) -> void:
	draw_rect(Rect2(p - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), cor)

func _draw() -> void:
	if mundo == null or tex == null:
		return
	var mapa: Mapa = mundo.mapa
	var h = mundo.herois[mundo.ativo_k]
	var hx: float = h.global_position.x
	var hy: float = h.global_position.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.04, 0.78))
	var esc: float
	var org: Vector2           # canto sup. esquerdo do recorte, em tiles (x, y_topo)
	if grande:
		esc = minf(size.x / Mapa.W, size.y / Mapa.H)
		org = Vector2(0, Mapa.H)
		var larg := Mapa.W * esc
		var alt := Mapa.H * esc
		var off := Vector2((size.x - larg) * 0.5, (size.y - alt) * 0.5)
		draw_texture_rect(tex, Rect2(off, Vector2(larg, alt)), false)
		_marcadores(mapa, func(px: float, py: float) -> Vector2: return off + Vector2(px * esc, (Mapa.H - py) * esc), 4.0, hx, hy)
		# nomes dos setores (só os já visitados)
		for r in Mapa.SETOR_RECTS:
			var cx: float = (r[1] + r[3]) * 0.5
			var cy: float = (r[2] + r[4]) * 0.5
			if mundo.setor_visitado(r[0]):
				var f := ThemeDB.fallback_font
				var nome: String = Game.SETORES[r[0]]["nome"]
				var pos := off + Vector2(cx * esc, (Mapa.H - cy) * esc)
				draw_string(f, pos - Vector2(nome.length() * 3.0, 0), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.75))
	else:
		esc = 4.0
		var vis_w := size.x / esc
		var vis_h := size.y / esc
		var x0 := clampf(hx - vis_w * 0.5, 0.0, Mapa.W - vis_w)
		var y0 := clampf(hy - vis_h * 0.5, 0.0, Mapa.H - vis_h)
		# imagem tem y invertido (linha 0 = topo do mundo)
		var src := Rect2(x0, Mapa.H - (y0 + vis_h), vis_w, vis_h)
		draw_texture_rect_region(tex, Rect2(Vector2.ZERO, size), src)
		_marcadores(mapa, func(px: float, py: float) -> Vector2: return Vector2((px - x0) * esc, (y0 + vis_h - py) * esc), 4.0, hx, hy)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.7, 0.35, 0.8), false, 2.0)

func _marcadores(mapa: Mapa, conv: Callable, tam: float, hx: float, hy: float) -> void:
	for b in mapa.bancos:
		if mundo.explorado_em(b["x"], b["y"]):
			_desenhar_marcador(conv.call(b["x"] + 0.5, b["y"] + 1.0), Color("ff9a3a"), tam + 1.0)
	for it in mapa.itens:
		if not Game.flags.get(it["id"], false) and mundo.explorado_em(int(it["x"]), int(it["y"])) and (it["req"] == "" or Game.flags.get(it["req"], false)):
			_desenhar_marcador(conv.call(it["x"] + 0.5, it["y"] + 1.0), Color("ffe14d"), tam)
	for a in mapa.arenas:
		if not Game.flags.get(a["flag"], false) and a["boss"] != "" and mundo.explorado_em(a["trig"][0], a["trig"][1]):
			var c: Vector2 = conv.call((a["trig"][0] + a["trig"][2]) * 0.5, a["trig"][1] + 2.0)
			_desenhar_marcador(c, Color("ff2a2a"), tam + 2.0)
	_desenhar_marcador(conv.call(hx, hy + 1.0), Color.WHITE, tam + 2.0)
