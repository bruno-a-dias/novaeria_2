class_name Art
extends RefCounted
## Sprites. Se existir res://assets/sprites/<chave>.png ele é usado; senão gera um placeholder pixel-art.

static var _cache := {}

# Altura em unidades de mundo de cada personagem (o sprite é escalado para essa altura).
const ALTURA := {
	"bron": 2.7, "solys": 2.7, "ziggs": 1.9, "sanguessuga": 2.1, "carnical": 2.5, "succubus": 2.4,
	"irma": 2.4, "capelao": 2.9, "besta": 4.0, "valerius": 3.7, "lyla": 2.8, "lyla_vampira": 2.9,
}

static func tem_arte(chave: String) -> bool:
	return ResourceLoader.exists("res://assets/sprites/%s.png" % chave)

## Aplica textura, escala (pelo tamanho real da imagem) e posição (pés no chão) ao Sprite3D.
static func configurar(sp: Sprite3D, chave: String) -> void:
	var t := tex(chave)
	sp.texture = t
	var alt: float = ALTURA.get(chave, 2.4)
	sp.pixel_size = alt / float(t.get_height())
	sp.position.y = alt * 0.5
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR if tem_arte(chave) else BaseMaterial3D.TEXTURE_FILTER_NEAREST

static func tex(chave: String) -> Texture2D:
	if _cache.has(chave):
		return _cache[chave]
	var t: Texture2D = null
	var caminho := "res://assets/sprites/%s.png" % chave
	if ResourceLoader.exists(caminho):
		t = load(caminho)
	if t == null:
		t = ImageTexture.create_from_image(_gerar(chave))
	_cache[chave] = t
	return t

static func _r(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for i in range(maxi(x, 0), mini(x + w, img.get_width())):
		for j in range(maxi(y, 0), mini(y + h, img.get_height())):
			img.set_pixel(i, j, c)

static func _gerar(k: String) -> Image:
	var img := Image.create(48, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var pele := Color("d9b99b")
	var ferro := Color("4a4a52")
	var escuro := Color("1b1b22")
	match k:
		"bron":
			_r(img, 14, 46, 8, 16, ferro); _r(img, 26, 46, 8, 16, ferro)             # pernas
			_r(img, 12, 22, 24, 26, Color("55555e"))                                  # armadura
			_r(img, 12, 40, 24, 4, Color("9c6b30"))                                   # cinto bronze
			_r(img, 8, 20, 32, 6, Color("6b4a2f"))                                    # capa de lobo
			_r(img, 14, 10, 20, 14, pele); _r(img, 14, 8, 20, 5, escuro)              # rosto + cabelo
			_r(img, 16, 18, 16, 6, Color("1c1410"))                                   # barba
			_r(img, 14, 24, 20, 4, Color("8e1b1b"))                                   # cachecol vermelho
			_r(img, 38, 4, 4, 40, Color("b9bcc4")); _r(img, 36, 40, 8, 4, Color("9c6b30"))  # espada
			_r(img, 4, 30, 8, 8, Color("777"))                                        # manopla
		"solys":
			_r(img, 15, 40, 18, 22, Color("f2efe6"))                                  # túnica
			_r(img, 13, 22, 22, 22, Color("f8f6ee")); _r(img, 13, 34, 22, 3, Color("e0b84a"))
			_r(img, 12, 20, 8, 5, Color("d4a017")); _r(img, 28, 20, 8, 5, Color("d4a017"))  # ombreiras
			_r(img, 16, 8, 16, 14, pele)
			_r(img, 12, 6, 24, 6, Color("d9dde3")); _r(img, 10, 10, 6, 30, Color("d9dde3")); _r(img, 32, 10, 6, 30, Color("d9dde3"))  # cabelo prateado
			_r(img, 19, 14, 3, 2, Color("ffd34d")); _r(img, 26, 14, 3, 2, Color("ffd34d"))  # olhos dourados
			_r(img, 40, 2, 3, 58, Color("e0b84a")); _r(img, 37, 0, 9, 8, Color("8fe3ff"))   # cajado + orbe
			_r(img, 30, 38, 8, 6, Color("c9a227"))                                    # grimório
		"ziggs":
			_r(img, 16, 48, 6, 14, Color("3f7a33")); _r(img, 26, 48, 6, 14, Color("3f7a33"))
			_r(img, 12, 32, 24, 18, Color("6b4a2f"))                                  # colete de couro
			_r(img, 8, 12, 32, 22, Color("5fae4a"))                                   # cabeça goblin
			_r(img, 2, 16, 8, 5, Color("5fae4a")); _r(img, 38, 16, 8, 5, Color("5fae4a"))  # orelhas
			_r(img, 12, 16, 10, 8, Color("c6b25a")); _r(img, 26, 16, 10, 8, Color("c6b25a"))  # óculos
			_r(img, 15, 18, 4, 4, escuro); _r(img, 29, 18, 4, 4, escuro)
			_r(img, 36, 36, 10, 8, Color("8a6a2a")); _r(img, 40, 30, 3, 8, Color("999"))    # engenhoca a vapor
		"sanguessuga":
			_r(img, 14, 44, 8, 18, Color("3a2a2a")); _r(img, 26, 44, 8, 18, Color("3a2a2a"))
			_r(img, 12, 22, 24, 24, Color("5a3535"))
			_r(img, 10, 18, 10, 18, Color("8a8a92")); _r(img, 14, 8, 20, 14, Color("b79a85"))   # tanque nas costas, cabeça
			_r(img, 18, 14, 4, 3, Color("ff3b3b")); _r(img, 28, 14, 4, 3, Color("ff3b3b"))
			_r(img, 36, 30, 10, 3, Color("aaa"))                                      # perfurador
		"carnical":
			_r(img, 10, 44, 12, 18, Color("2a2a30")); _r(img, 26, 44, 12, 18, Color("2a2a30"))
			_r(img, 6, 14, 36, 34, Color("3d3d46")); _r(img, 12, 20, 24, 18, Color("7a2020"))   # caldeira
			_r(img, 18, 2, 12, 14, Color("7d8a6a")); _r(img, 20, 6, 3, 3, Color("ffb347")); _r(img, 26, 6, 3, 3, Color("ffb347"))
			_r(img, 22, 10, 4, 6, Color("ddd"))                                       # vapor
		"succubus":
			_r(img, 16, 30, 16, 28, Color("7a1230"))                                  # vestido
			_r(img, 6, 14, 12, 18, Color("3b0d2a")); _r(img, 30, 14, 12, 18, Color("3b0d2a"))  # asas
			_r(img, 17, 8, 14, 14, Color("e7b5b5")); _r(img, 15, 6, 18, 5, Color("2a0a1f"))
			_r(img, 19, 14, 3, 2, Color("ff2a55")); _r(img, 27, 14, 3, 2, Color("ff2a55"))
			_r(img, 20, 4, 3, 5, Color("c4143c")); _r(img, 26, 4, 3, 5, Color("c4143c"))        # chifres
		"irma":
			_r(img, 14, 46, 7, 16, escuro); _r(img, 27, 46, 7, 16, escuro)
			_r(img, 12, 26, 24, 22, Color("2d2d35"))
			_r(img, 14, 10, 20, 18, Color("e8e8e8")); _r(img, 16, 14, 16, 8, Color("20202a"))   # touca/rosto
			_r(img, 2, 22, 10, 3, Color("c0c4cc")); _r(img, 36, 22, 10, 3, Color("c0c4cc")); _r(img, 4, 30, 8, 3, Color("c0c4cc"))  # membros de aço
			_r(img, 38, 34, 8, 3, Color("ff5577"))                                    # lâmina-seringa
		"capelao":
			_r(img, 10, 18, 28, 44, Color("3a3a40")); _r(img, 12, 20, 24, 8, Color("55555e"))
			_r(img, 14, 4, 20, 16, Color("a99888")); _r(img, 12, 2, 24, 6, Color("2a2a30"))
			_r(img, 19, 10, 3, 3, Color("ff9a3b")); _r(img, 27, 10, 3, 3, Color("ff9a3b"))
			_r(img, 4, 36, 10, 10, Color("8a5a1a")); _r(img, 6, 46, 2, 12, Color("999"))        # incensário
		"besta":
			_r(img, 6, 40, 14, 22, Color("5a2a2a")); _r(img, 28, 40, 14, 22, Color("5a2a2a"))
			_r(img, 2, 10, 44, 34, Color("7d3030")); _r(img, 8, 18, 10, 20, Color("888894")); _r(img, 30, 14, 10, 24, Color("888894"))
			_r(img, 16, 0, 16, 14, Color("9a5a5a")); _r(img, 20, 5, 3, 3, Color("ffe14d")); _r(img, 26, 5, 3, 3, Color("ffe14d"))
		"valerius":
			_r(img, 12, 46, 9, 16, Color("23232b")); _r(img, 27, 46, 9, 16, Color("23232b"))
			_r(img, 6, 16, 36, 32, Color("1c1c24")); _r(img, 10, 22, 28, 4, Color("8a8a96")); _r(img, 20, 28, 8, 12, Color("b01030"))  # gota de sangue
			_r(img, 0, 18, 8, 14, Color("6a6a76")); _r(img, 40, 18, 8, 14, Color("6a6a76"))    # pistões nos ombros
			_r(img, 16, 2, 16, 16, Color("2e2e38")); _r(img, 19, 8, 4, 3, Color("ff2040")); _r(img, 26, 8, 4, 3, Color("ff2040"))
			_r(img, 38, 6, 6, 46, Color("a8a8b4"))                                    # lâmina de ferro
		"lyla":
			_r(img, 10, 26, 28, 36, Color("8a1030"))                                  # vestido carmesim
			_r(img, 2, 18, 8, 44, Color("4a1070")); _r(img, 38, 18, 8, 44, Color("4a1070"))   # capa roxa
			_r(img, 12, 26, 24, 4, Color("e0b84a")); _r(img, 12, 44, 24, 2, Color("e0b84a"))
			_r(img, 16, 6, 16, 16, Color("cfc0e0")); _r(img, 12, 2, 24, 8, Color("140818"))   # pele lilás, cabelo negro
			_r(img, 12, 8, 6, 36, Color("140818")); _r(img, 30, 8, 6, 36, Color("140818"))
			_r(img, 19, 12, 3, 3, Color("ff1744")); _r(img, 26, 12, 3, 3, Color("ff1744"))     # olhos brilhantes
			_r(img, 21, 18, 2, 3, Color("fff")); _r(img, 25, 18, 2, 3, Color("fff"))           # presas
		"lyla_vampira":
			_r(img, 8, 24, 32, 38, Color("5a0820")); _r(img, 0, 8, 10, 40, Color("2a0640")); _r(img, 38, 8, 10, 40, Color("2a0640"))
			_r(img, 14, 4, 20, 18, Color("b8a8d0")); _r(img, 10, 0, 28, 8, Color("0c0410"))
			_r(img, 18, 11, 4, 4, Color("ff0033")); _r(img, 26, 11, 4, 4, Color("ff0033"))
			_r(img, 20, 18, 3, 6, Color("fff")); _r(img, 25, 18, 3, 6, Color("fff"))
			_r(img, 0, 30, 10, 3, Color("d0103a")); _r(img, 38, 30, 10, 3, Color("d0103a"))   # garras de sangue
		_:
			_r(img, 16, 16, 16, 32, Color("999"))
	return img
