# CG-ProjetoAB2 - Godot 4
##Alunos : Hugo Stankowich, Lucca Paes e Renato Coca

Projeto de computacao grafica feito em Godot 4: uma demo 3D de futebol com jogador controlavel, camera de transmissao, IA simples para os times, goleiros, placar, sons, reinicios de jogo e power-ups.

## Como abrir

1. Instale o Godot 4.6, versao standard.
2. Abra o Godot e importe esta pasta pelo arquivo `project.godot`.
3. Abra a cena `res://scenes/Main.tscn`.
4. Aperte F5 para rodar o projeto.

## Controles

- `W`, `A`, `S`, `D`: mover o jogador.
- `Shift`: correr.
- `L`: tentar controlar ou conduzir a bola.
- `K` ou botao esquerdo do mouse: carregar e chutar.
- `J`: desarme.

## Estrutura principal

```text
project.godot
scenes/
  Main.tscn
  Player.tscn
scripts/
  Main.gd
  Player.gd
  BroadcastCamera.gd
  StadiumLights.gd
  StadiumColliders.gd
  CrowdColors.gd
  StarSpin.gd
  KeeperStandStill.gd
models/
anims/
audio/
textures/
shaders/
placar.png
```

## Arquivos importantes

- `scripts/Main.gd`: regra principal da partida, IA, laterais, tiros de meta, gols, goleiros, power-ups e placar.
- `scripts/Player.gd`: movimento do jogador, corrida, chute, controle de bola e carrinho.
- `scripts/BroadcastCamera.gd`: camera principal do jogo.
- `scenes/Main.tscn`: cena principal com campo, jogadores, bola, gols, camera e objetos do estadio.
- `scenes/Player.tscn`: cena base do jogador controlavel.
