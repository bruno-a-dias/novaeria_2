extends Node
## Fluxo do jogo: título → prólogo → mundo único (histórias entram como cenas dentro do mapa) → epílogo.

var ui: CanvasLayer
var fundo: ColorRect
var titulo: Label
var texto: Label
var dica: Label
var mundo: World = null
var fila: Array = []
var depois: Callable
var modo := "titulo"
var pendentes: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui = CanvasLayer.new()
	ui.layer = 50
	add_child(ui)
	fundo = ColorRect.new()
	fundo.color = Color(0.03, 0.02, 0.05)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(fundo)
	titulo = Label.new()
	titulo.position = Vector2(0, 100)
	titulo.size = Vector2(1280, 150)
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 52)
	titulo.modulate = Color("d8b04a")
	ui.add_child(titulo)
	texto = Label.new()
	texto.position = Vector2(180, 280)
	texto.size = Vector2(920, 300)
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.add_theme_font_size_override("font_size", 24)
	ui.add_child(texto)
	dica = Label.new()
	dica.position = Vector2(340, 640)
	dica.size = Vector2(600, 40)
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.modulate = Color(1, 1, 1, 0.6)
	ui.add_child(dica)
	_mostrar_titulo()

func _input(ev: InputEvent) -> void:
	if not ev.is_action_pressed("confirm") or ui.visible == false:
		return
	match modo:
		"titulo":
			Game.novo_jogo()
			_historia(Game.PROLOGO, func(): _iniciar_mundo())
		"historia", "modal":
			if fila.is_empty():
				depois.call()
			else:
				texto.text = fila.pop_front()
		"fim":
			_mostrar_titulo()

func _mostrar_titulo() -> void:
	modo = "titulo"
	ui.visible = true
	if mundo != null:
		mundo.queue_free()
		mundo = null
	get_tree().paused = false
	fundo.color = Color(0.03, 0.02, 0.05)
	titulo.text = "NOVAÉRIA\nO BEIJO DA MORTE"
	texto.text = "Livro 2 — Metroidvania de ação 2.5D\n\nBron  •  Solys Regis  •  Ziggs Spark\n\nUm único mapa interligado: da Estalagem do Cervo Prateado ao Altar de Lyla."
	dica.text = "Pressione ENTER / ESPAÇO para começar"

func _historia(linhas: Array, quando_acabar: Callable, tit: String = "") -> void:
	modo = "historia"
	ui.visible = true
	titulo.text = tit
	fila = linhas.duplicate()
	depois = quando_acabar
	if fila.is_empty():
		depois.call()
		return
	texto.text = fila.pop_front()
	dica.text = "ENTER / ESPAÇO para continuar"

func _iniciar_mundo() -> void:
	ui.visible = false
	modo = "luta"
	if mundo != null:
		mundo.queue_free()
	mundo = World.new()
	mundo.terminou.connect(_mundo_acabou)
	mundo.historia_pedida.connect(_pedido_historia)
	add_child(mundo)

# Cenas de história durante a exploração (pausam o mundo)
func _pedido_historia(linhas: Array, tit: String) -> void:
	pendentes.append([linhas, tit])
	if modo != "modal":
		_proximo_modal()

func _proximo_modal() -> void:
	if pendentes.is_empty():
		return
	var p: Array = pendentes.pop_front()
	modo = "modal"
	get_tree().paused = true
	if mundo != null:
		mundo.modal = true
	ui.visible = true
	fundo.color = Color(0.03, 0.02, 0.05, 0.86)
	titulo.text = p[1]
	titulo.add_theme_font_size_override("font_size", 38)
	fila = p[0].duplicate()
	depois = _fechar_modal
	texto.text = fila.pop_front() if not fila.is_empty() else ""
	dica.text = "ENTER / ESPAÇO para continuar"

func _fechar_modal() -> void:
	if not pendentes.is_empty():
		_proximo_modal()
		return
	ui.visible = false
	modo = "luta"
	titulo.add_theme_font_size_override("font_size", 52)
	get_tree().paused = false
	if mundo != null:
		mundo.modal = false

func _mundo_acabou(_vitoria: bool) -> void:
	if mundo != null:
		mundo.queue_free()
		mundo = null
	fundo.color = Color(0.03, 0.02, 0.05)
	_historia(Game.EPILOGO, _fim_do_jogo, "O Amanhecer de Novaéria")

func _fim_do_jogo() -> void:
	modo = "fim"
	titulo.text = "FIM"
	texto.text = "Obrigado por jogar.\nHeróis caídos durante a jornada: %d" % Game.mortes_total
	dica.text = "ENTER para voltar ao título"
