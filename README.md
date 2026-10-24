# Novaéria: O Beijo da Morte — Jogo (Godot 4.3)

Metroidvania de ação **2.5D (HD-2D)** baseado no Livro 2 da saga Novaéria: mundo 3D com câmera ortográfica e sprites *billboard*, iluminação dinâmica (Forward+), troca de personagens em tempo real e dois recursos duplos (**Pressão a Vácuo** e **Contaminação Sanguínea**).

## Como abrir e jogar
1. Instale o **Godot 4.3** (ou superior 4.x): https://godotengine.org/download
2. Abra o Godot → *Importar* → selecione `project.godot` desta pasta.
3. Pressione **F5** (cena principal: `scenes/main.tscn`).

## O mapa único (estilo Hollow Knight)
Em vez de fases separadas, o jogo agora é **um único mapa interligado** (metroidvania 2.5D, visão lateral), com os setores na ordem da história e com **atalhos, portões, fogueiras e itens de progressão**:

| Setor | Capítulo | O que há |
|---|---|---|
| Estalagem do Cervo Prateado | 8-10 | Salão (fogueira inicial), Pátio (arena: caçadores de Lyla), alçapão para o Porão (Fragmento de Coração) |
| Túneis de Aethelgard | — | Porão → túnel → **Toca do Goblin** (arena + **Propulsor de Ziggs**: pulo duplo) → túnel leste com atalho (Portão de Ferro) |
| Floresta de Oakhaven | 12 | Trilha e Clareira com plataformas, espinhos, **Cabana do Caçador** (Mapa Roubado), **Barreira de Sangue** |
| Ruínas de Kal-Drak | 14 | Pátio, poço de ascensão, Nave (fogueira + coração), **Altar da Besta** (chefe) e **Relíquia de Kal-Drak** |
| Perímetro da Cripta | 16 | Poço de descida, Corredor das Armadilhas (espinhos), **Portões da Cripta** (exigem a Relíquia), **Poço da Cripta** (exige pulo duplo) |
| Salão do Ritual | 17-18 | Antecâmara e arena de **Lorde Valerius** |
| Altar de Lyla | 19-20 | Escadaria Carmesim e arena final de **Lyla** (fim do jogo) |

**Progressão (portões do metroidvania):** Mapa Roubado abre a Barreira de Sangue → derrotar a Besta abre o poço para a Marcha e entrega a Relíquia → a Relíquia abre os Portões da Cripta → o Poço da Cripta só se sobe com o Propulsor (Túneis) → Valerius → Lyla. Os Fragmentos de Coração (+15 de vida máxima, 3 no mapa) estão em cantos escondidos.

**Fogueiras:** ao lado de uma fogueira aperte **S / seta para baixo** para descansar: restaura o grupo, revive caídos, salva o ponto de retorno e faz os inimigos comuns reaparecerem. Se todo o grupo cair, ele volta à última fogueira.
**Mapa:** tecla **M** (ou Esc) abre o mapa completo com névoa de exploração, fogueiras, itens e chefes, mais o objetivo atual. Há também um minimapa no canto.

## Controles
| Ação | Teclado | Controle |
|---|---|---|
| Mover | A/D ou setas | Analógico esquerdo |
| Pular / pulo duplo | Espaço, W ou seta cima | A |
| Descer de plataforma | S/baixo + pular | |
| Ataque básico | J / clique | X |
| Habilidade 1 / 2 | K / L | B / Y |
| Suprema | I (ou R) | Clique do analógico direito |
| Trocar herói | Q / E, ou 1-2-3 | LB / RB |
| Descansar na fogueira | S / baixo | |
| Mapa / Pausa | M, Tab ou Esc | Back |
| Confirmar história | Enter / Espaço | A |

## Heróis (conforme os Documentos de Design)
- **Bron** — Tanque / Quebra de Postura. Combo pesado de 3 golpes (movimento −70% na recuperação), *Impacto de Runas* (cone + knockback), *Aparar* (guarda; parry perfeito atordoa), *Fúria do Gladiador* (suprema).
- **Solys Regis** — Suporte / Dano sagrado. *Chicote de Chamas* (puxa e aplica Expiação), *Pira de Julgamento* (0,4 s de atraso + área em chamas por 4 s), *Bênção de Solys* (cura + purifica), *Expurgo da Chama Prateada* (360°, silencia, cura). Luz do cajado pulsante (OmniLight3D #FFE89C).
- **Ziggs Spark** — Controle de área. Estilhaços a vapor, *Torreta de Pressão a Vácuo*, *Mina de Impacto Expansivo*, *Injetor de Adrenalina* (buff de grupo). Acima de 100% de pressão ele superaquece.

**Contaminação Sanguínea:** ataques do Culto enchem a barra roxa; ≥50% reduz velocidade, ≥80% aumenta o dano sofrido e drena vida. Solys purifica.

## Inimigos e chefes
Sanguessugas de Sucata, Carniçais de Caldeira (estouram em vapor), Súcubo de Sangue (flutua, projéteis de sangue), Irmã da Agulha (dash com *ghosting*), Capelão de Ferro (giro do incensário em área, cura aliados), **A Besta de Transfusão** (minichefe), **Lorde Valerius** e **Lyla** (a Rainha da Ruína; forma humana → vampira em 50%; *Beijo da Morte* pode ser **quebrado** com 70 de dano durante a canalização).

## Arte: como usar seus sprites
Os sprites reais já estão em `assets/sprites/` (recortados das suas pranchas). Se faltar algum arquivo, o jogo gera um placeholder. Para trocar a arte, coloque PNGs com fundo transparente em `assets/sprites/` com estes nomes (o jogo detecta sozinho, sem mexer no código):
`bron, solys, ziggs, sanguessuga, carnical, succubus, irma, capelao, besta, valerius, lyla, lyla_vampira`

As pranchas originais (`Sprite_Sucubo_Sangue_25D.jpg`, `Sprite_Irma_Agulha_25D.jpg`, `Sprite_Capelao_Ferro_25D.jpg`, `Lyla_Forma_Humana.jpg`, `Novaeria_Grid_Personagens.jpg`, ...) foram usadas para os recortes. Animação por quadros (`AnimatedSprite3D`) é o próximo passo natural: `scripts/hero.gd` e `scripts/enemy.gd` usam um `Sprite3D` por personagem.

## Estrutura
```
project.godot
scenes/main.tscn          cena principal (fluxo)
scripts/game.gd           autoload: heróis, setores (história/atmosfera), flags de progresso, inputs
scripts/main.gd           título, prólogo, cenas de história sobre o mapa, epílogo
scripts/mapa.gd           O MAPA: grade de tiles, salas, portões, fogueiras, itens, arenas e física de colisão
scripts/cenario.gd        constrói o cenário 3D a partir do mapa (terreno, fundos, decoração, luzes)
scripts/world.gd          mundo: câmera lateral, setores, arenas/chefes, itens, fogueiras, HUD
scripts/minimapa.gd       minimapa e mapa completo com névoa de exploração
scripts/hero.gd           heróis (pulo, pulo duplo, habilidades)
scripts/enemy.gd          inimigos e chefes (IAs de plataforma)
scripts/proj.gd           projéteis, torreta, minas, zonas de fogo
scripts/fx.gd, art.gd     efeitos visuais e sprites
tests/alcance.gd          valida o mapa simulando a física real (progressão e pulo duplo)
tests/smoke.tscn          teste de fumaça (percorre os setores com entradas aleatórias)
```
Para editar o mapa, mexa em `scripts/mapa.gd` (funções `sala`, `plat`, `portao`, `banco`, `item`...). Depois rode o teste de alcance para garantir que nada ficou inacessível:
`godot --headless --path . -s tests/alcance.gd` · fumaça: `godot --headless --path . res://tests/smoke.tscn`

## Pendências sugeridas
Animações por quadro, trilha/efeitos sonoros (rock/metal sombrio), normal maps nos sprites, arremesso de gancho do Bron e Lyla jogável (os documentos antigos a tratavam como aliada; o documento atualizado a define como vilã suprema — o jogo segue o atualizado).

## Versão web (jogar no navegador)
O build HTML5 (renderer Compatibility) está em `Novaeria_web_build.zip`. Para testar:
- **Local:** extraia o zip e, dentro da pasta, rode `python -m http.server 8000`; abra http://localhost:8000
- **Online (Vercel):** extraia o zip e rode `npx vercel --prod` dentro da pasta (aceite os padrões; é um site estático).
- **Online (Netlify):** arraste a pasta extraída em https://app.netlify.com/drop
Para reexportar: instale os templates de exportação do Godot 4.3 e use `godot --headless --path . --export-release Web build/web/index.html` (preset "Web" já configurado em `export_presets.cfg`).
