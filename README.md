# StadiumGL — Teste do pipeline Blender → OBJ/MTL → OpenGL

Renderização inicial do estádio low-poly em C++ com OpenGL clássico + GLUT, pra validar que o modelo, textura, escala e câmera estão corretos antes de adicionar mecânicas.

## Estrutura

```
StadiumGL/
├── Makefile
├── README.md
├── src/
│   └── main.cpp                 ← código principal
├── include/
│   └── stb_image.h              ← você precisa baixar (passo abaixo)
└── assets/
    ├── models/
    │   ├── stadium.obj          ← exportado do Blender
    │   └── stadium.mtl
    └── textures/
        └── ColorRamp.png
```

## Setup em 3 passos

### 1) Baixar `stb_image.h`

Single-header de ~7k linhas pra carregar PNG. Baixa daqui:

https://raw.githubusercontent.com/nothings/stb/master/stb_image.h

Coloca em `include/stb_image.h`. Comando direto pelo terminal:

```bash
cd StadiumGL
curl -L -o include/stb_image.h https://raw.githubusercontent.com/nothings/stb/master/stb_image.h
```

### 2) Compilar

```bash
make
```

No macOS pode aparecer um warning sobre GLUT estar deprecated — é só warning, ignora. O binário é gerado como `./stadium`.

### 3) Rodar

**Importante:** roda a partir da raiz do projeto (paths em `main.cpp` são relativos).

```bash
./stadium
```

Ou direto:

```bash
make run
```

## Controles

| Tecla       | Ação                                 |
| ----------- | ------------------------------------ |
| W A S D     | Mover câmera (frente / lados / trás) |
| Q / E       | Descer / subir                       |
| ← → ↑ ↓     | Olhar (yaw / pitch)                  |
| `+` / `-`   | Aumentar / diminuir velocidade       |
| R           | Reset da câmera                      |
| ESC         | Sair                                 |

## O que esperar no primeiro render

- Janela 1280×800 fundo cinza escuro
- Estádio centralizado em (0,0,0), maior dimensão ~30 unidades
- Câmera inicial em (0, 8, 35) olhando pra origem com pitch -10°
- Iluminação direcional vinda do alto-direita (simulando sol)
- Materiais com textura: ColorRamp.png aplicada via `GL_NEAREST` (faixas de cor nítidas)
- Materiais sem textura: cor sólida do `Kd` (scoreboard preto, refletores brancos amarelados, torcida colorida, etc.)
- Sem efeitos emissivos por enquanto — qualquer "Ke" no MTL é ignorado neste teste

## Diagnóstico

O `main.cpp` imprime no terminal o que carregou. Esperado:

```
[mtl] 12 materiais carregados de assets/models/stadium.mtl
[textura] assets/models/../textures/ColorRamp.png 64x64 canais=4
[obj] 13062 vertices, 4438 normais, 116 UVs, 23 grupos
```

Se o estádio aparecer **todo preto**: provavelmente luz não está chegando — verifica a posição da luz (linha do `glLightfv(GL_LIGHT0, GL_POSITION, ...)` no `display()`).

Se a **textura aparece manchada/borrada**: você ligou `GL_LINEAR` em vez de `GL_NEAREST`.

Se o estádio aparece **rosa/magenta**: a textura não carregou. Confira o terminal pelo erro do stb_image. Provavelmente o working directory está errado — rode de dentro de `StadiumGL/`, não de outro lugar.

Se aparece com **buracos / faces faltando**: as normais estão invertidas em alguns triângulos. O `glLightModeli(GL_LIGHT_MODEL_TWO_SIDE, GL_TRUE)` já deve resolver isso, mas se ainda persistir, comenta a linha `glEnable(GL_CULL_FACE)` (já está comentada por default).

## Próximos passos (não implementados ainda)

Quando o teste estiver visualmente OK, podemos voltar pra adicionar:

- Glow / emissive no scoreboard, refletores e estrela (precisa de shader GLSL ou multipass)
- Spotlights reais como `GL_LIGHT1..7` apontando do alto pro campo
- Skybox/skydome noturno
- Bola e jogadores
- Animação de torcida (vertex shader simples)
