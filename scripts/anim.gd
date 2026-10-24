class_name Anim
extends RefCounted
## Animação de personagens.
## 1) Se existir res://assets/sprites/<chave>_sheet.png, usa a folha de quadros (grade COLS x LINHAS):
##    linha 0 = parado, 1 = andar, 2 = pulo, 3 = golpe, 4 = dano (quadros por linha em QUADROS).
## 2) Senão, anima o sprite estático como um "fantoche": respiração, passada com balanço e inclinação,
##    esticar/achatar no pulo e na aterrissagem, avanço no golpe e tremor ao levar dano.

const COLS := 6
const LINHAS := 5
const QUADROS := [4, 6, 2, 5, 2]         # parado, andar, pulo, golpe, dano
const FPS := [6.0, 12.0, 6.0, 16.0, 8.0]
enum { PARADO, ANDAR, PULO, GOLPE, DANO }

var sp: Sprite3D
var chave: String
var altura := 2.4
var folha := false
var passo := 0.0
var t := 0.0
var estado := PARADO
var _quadro_t := 0.0
var _no_chao_antes := true
var _aterrissa_t := 0.0
var _golpe_t := 0.0
var _golpe_dur := 0.25
var _golpe_av := 0.0
var _dano_t := 0.0
var _lado := 1.0
var x_base := 0.0
var _pes_y := 0.0
var _off_x := 0.0
const CORPO_X := 110.0

func _init(sprite: Sprite3D, k: String) -> void:
	sp = sprite
	chave = k
	altura = Art.ALTURA.get(k, 2.4)
	var caminho := "res://assets/sprites/%s_sheet.png" % k
	if ResourceLoader.exists(caminho):
		var tex: Texture2D = load(caminho)
		sp.texture = tex
		sp.hframes = COLS
		sp.vframes = LINHAS
		# o personagem ocupa ~80% da altura da célula (154 de 192 px) e os pés ficam 6 px acima da base
		var cel_h := float(tex.get_height()) / LINHAS
		_off_x = float(tex.get_width()) / COLS * 0.5 - CORPO_X     # o corpo fica a CORPO_X px da borda esquerda da célula
		sp.pixel_size = altura / (cel_h * 0.8021)
		_pes_y = (cel_h - 6.0 - cel_h * 0.5) * sp.pixel_size
		sp.position.y = _pes_y
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		folha = true
	else:
		# sem billboard para poder inclinar o sprite (a câmera é fixa, só inclinada 8° em X)
		sp.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sp.rotation_degrees.x = -8.0

func golpe(avanco: float = 0.4, dur: float = 0.25) -> void:
	_golpe_t = dur
	_golpe_dur = dur
	_golpe_av = avanco
	if folha:
		_quadro_t = 0.0

func dano(dur: float = 0.3) -> void:
	_dano_t = dur

## vx: velocidade horizontal; vy: vertical; face: +1/-1; vmax: velocidade de corrida.
func atualizar(dt: float, vx: float, vy: float, no_chao: bool, face: float, vmax: float = 6.0, extra_y: float = 0.0) -> void:
	t += dt
	_lado = face
	if no_chao and not _no_chao_antes:
		_aterrissa_t = 0.14
	_no_chao_antes = no_chao
	_aterrissa_t = maxf(0.0, _aterrissa_t - dt)
	_golpe_t = maxf(0.0, _golpe_t - dt)
	_dano_t = maxf(0.0, _dano_t - dt)
	var anda := no_chao and absf(vx) > 0.4
	if _dano_t > 0.0:
		estado = DANO
	elif _golpe_t > 0.0:
		estado = GOLPE
	elif not no_chao:
		estado = PULO
	elif anda:
		estado = ANDAR
	else:
		estado = PARADO
	if anda:
		passo += dt * (9.0 + 5.0 * clampf(absf(vx) / vmax, 0.0, 1.5))
	if folha:
		_atualizar_folha(dt, vy, extra_y)
	else:
		_atualizar_fantoche(dt, vx, vy, no_chao, vmax, extra_y)

func _atualizar_folha(dt: float, vy: float, extra_y: float) -> void:
	var n: int = QUADROS[estado]
	var f := 0
	if estado == PULO:
		f = 0 if vy > 0.0 else mini(1, n - 1)
	elif estado == GOLPE:
		f = mini(n - 1, int((1.0 - _golpe_t / maxf(_golpe_dur, 0.01)) * n))
	else:
		_quadro_t += dt * FPS[estado]
		f = int(_quadro_t) % n
	sp.frame = estado * COLS + f
	sp.offset.x = _off_x * (-1.0 if sp.flip_h else 1.0)
	sp.position.y = _pes_y + extra_y

func _atualizar_fantoche(dt: float, vx: float, vy: float, no_chao: bool, vmax: float, extra_y: float) -> void:
	var sx := 1.0
	var sy := 1.0
	var rot := 0.0           # rotação em Z (rad), pivô nos pés
	var dx := 0.0
	var dy := 0.0
	match estado:
		PARADO:
			var r := sin(t * 2.4)
			sy = 1.0 + 0.022 * r
			sx = 1.0 - 0.012 * r
			rot = 0.012 * sin(t * 1.2)
		ANDAR:
			var s := sin(passo)
			var forte := clampf(absf(vx) / vmax, 0.3, 1.4)
			dy = absf(s) * 0.12 * forte                        # quica a cada passo
			rot = -_lado * 0.10 * forte + s * 0.07             # inclina p/ frente + balanço de passada
			sy = 1.0 + 0.04 * cos(passo * 2.0)                 # achata ao tocar o chão
			sx = 1.0 - 0.025 * cos(passo * 2.0)
			dx = _lado * 0.03 * s
		PULO:
			if vy > 1.0:
				sx = 0.90
				sy = 1.14
			elif vy < -1.0:
				sx = 1.06
				sy = 0.94
			rot = -_lado * 0.08
		GOLPE:
			var p := 1.0 - _golpe_t / maxf(_golpe_dur, 0.01)    # 0..1
			var curva := sin(p * PI)                            # sobe e desce
			dx = _lado * _golpe_av * curva
			rot = -_lado * 0.28 * curva
			sx = 1.0 + 0.10 * curva
			sy = 1.0 - 0.07 * curva
		DANO:
			dx = sin(t * 70.0) * 0.08
			rot = -_lado * 0.12
			sx = 1.08
			sy = 0.92
	if _aterrissa_t > 0.0 and estado != GOLPE and estado != DANO:
		var q := _aterrissa_t / 0.14
		sx *= 1.0 + 0.18 * q
		sy *= 1.0 - 0.16 * q
	sp.scale = Vector3(sx, sy, 1.0)
	sp.rotation.z = rot
	# pivô nos pés: posição do centro depois de escalar e girar
	var meia := altura * 0.5 * sy
	sp.position.x = x_base + dx - sin(rot) * meia
	sp.position.y = cos(rot) * meia + dy + extra_y
