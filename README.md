# CG-ProjetoAB2 — Versão Godot 4

Demo de futebol em terceira pessoa rodando em Godot 4.6 (Forward+).
Substitui o build OpenGL clássico para ter PBR, sombras e animações de GLB
funcionando de graça.

## Como rodar

1. Instale o **Godot 4.6** (download: <https://godotengine.org/download>). Use a build padrão (não a "- .NET").
2. Abra o Godot, clique em **Import**, aponte pra esta pasta (`godot/`),
   selecione `project.godot`.
3. O editor abre. Aperte **F5** (ou o ícone de play no canto superior direito).
4. Vai aparecer um campo gramado, um jogador (cápsula vermelha — placeholder),
   um goleiro (cápsula preta) e uma estrela (prisma dourado girando).

## Controles

| tecla        | ação                              |
|--------------|-----------------------------------|
| `W A S D`    | mover (relativo à câmera)         |
| `Mouse`      | olhar (Yaw no corpo, Pitch na câmera) |
| `Espaço`     | pular                             |
| `Shift`      | sprint                            |
| `Click esq.` | (reservado para chutar)           |
| `ESC`        | libera o mouse                    |

## Estrutura do projeto

```
godot/
├── project.godot          # config do Godot
├── icon.svg               # ícone do projeto
├── models/
│   ├── stadium_high.obj   # estádio 40×10.6×26.6 m
│   └── players/           # 8 jogadores (4 teamA + 4 teamB)
├── textures/
│   ├── stadium/*.png      # baseColor + normal + emissive
│   └── players/           # 2 atlases (teamA, teamB)
├── scenes/
│   ├── Main.tscn          # mundo: estádio, sol, ambiente PBR, 8 jogadores, bola, estrela
│   └── Player.tscn        # jogador controlável: CharacterBody3D + câmera 3ª pessoa
└── scripts/
    ├── Player.gd          # WASD + mouse + pulo + sprint
    └── StarSpin.gd        # estrela girando e flutuando
```

## Status dos modelos

| nó na cena | modelo | posição |
|---|---|---|
| Player (controlável) | teamA_player_01.obj | (0, 0, 0) |
| TeamA_02 | teamA_player_02.obj | (-8, 0, -2) |
| TeamA_03 | teamA_player_03.obj | (8, 0, -2) |
| TeamA_04 | teamA_player_04.obj | (0, 0, 4) |
| Goalkeeper | teamB_player_01.obj (rotacionado 180°) | (0, 0, -12.5) |
| TeamB_02..04 | teamB_player_02..04.obj (rotacionados 180°) | região defensiva |
| Stadium | stadium_high.obj | origem |
| Star (power-up) | placeholder (PrismMesh dourado) | (-5, 0.8, 5) |
| Ball | placeholder (SphereMesh branca) | (0, 0.3, -2) |

## Roadmap (3 dias)

- [x] Dia 1: Scaffold + jogador + câmera + ambiente PBR + placeholders
- [ ] Dia 2: Chute (apply_impulse na bola), 7 NPCs com IA mínima, animação do goleiro
- [ ] Dia 3: Power-up (Area3D na estrela), placar, gol (Area3D no fundo da rede), HUD
