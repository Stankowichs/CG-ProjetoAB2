// =============================================================================
// StadiumGL - Pipeline test: Blender -> OBJ/MTL -> OpenGL classic
// =============================================================================
//
// Objetivo deste arquivo: renderizar o estádio exportado do Blender,
// verificando se geometria, normais, UVs, materiais e texturas do estádio
// estão funcionando corretamente.
//
// Controles:
//   W A S D    Mover câmera (frente/esquerda/trás/direita)
//   Q E        Descer / subir
//   Setas      Olhar (yaw / pitch)
//   + / -      Aumentar / diminuir velocidade
//   R          Reset da câmera
//   L          Ativar/desativar marcadores dos holofotes
//   ESC        Sair
//
// Compilar (macOS):
//   g++ -std=c++17 -Wno-deprecated-declarations src/main.cpp \
//       -o stadium -framework OpenGL -framework GLUT
//
// Compilar (Linux):
//   g++ -std=c++17 src/main.cpp -o stadium -lGL -lGLU -lglut
//
// Executar a partir da raiz do projeto (importante - paths são relativos):
//   ./stadium
//
// Estrutura esperada de arquivos:
//   StadiumGL/
//   ├── stadium                       (binário)
//   ├── src/main.cpp                  (este arquivo)
//   ├── include/stb_image.h           (baixe de https://github.com/nothings/stb)
//   └── assets/
//       ├── models/stadium_high.obj
//       ├── models/stadium_high.mtl
//       └── textures/stadium/*.png
// =============================================================================

// ----- Headers de plataforma -----
#ifdef __APPLE__
    #include <GLUT/glut.h>
    #include <OpenGL/gl.h>
    #include <OpenGL/glu.h>
#else
    #include <GL/glut.h>
    #include <GL/gl.h>
    #include <GL/glu.h>
#endif

// stb_image: single-header de carregamento de imagens.
// O define ativa as implementações - precisa aparecer EXATAMENTE uma vez
// em todo o projeto.
#define STB_IMAGE_IMPLEMENTATION
#include "../include/stb_image.h"

#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <cstring>
#include <string>
#include <vector>
#include <map>
#include <fstream>
#include <sstream>
#include <iostream>
#include <algorithm>

// =============================================================================
// ESTRUTURAS DE DADOS
// =============================================================================

struct Vec3 { float x, y, z; };
struct Vec2 { float u, v; };

// Um vértice de face referencia 3 índices independentes no OBJ:
// um pra posição (v), um pra UV (vt) e um pra normal (vn).
// Usamos -1 quando o índice não está presente.
struct FaceVertex {
    int v  = -1;
    int vt = -1;
    int vn = -1;
};

// Material no formato MTL. Mantemos só os campos usados pelo fixed pipeline.
struct Material {
    std::string name;
    Vec3   Ka     = {0.2f, 0.2f, 0.2f};   // ambient
    Vec3   Kd     = {0.8f, 0.8f, 0.8f};   // diffuse
    Vec3   Ks     = {0.0f, 0.0f, 0.0f};   // specular
    float  Ns     = 32.0f;                 // shininess (0..1000 no MTL)
    std::string map_Kd;                    // path da textura difusa (se houver)
    GLuint texID  = 0;                     // 0 = sem textura
};

// Um "grupo" é um trecho contíguo de triângulos que compartilham material.
// Render = pra cada grupo, faz glBindTexture + glMaterial + glBegin/glEnd.
struct Group {
    std::string                materialName;
    std::vector<FaceVertex>    vertices;   // sempre múltiplo de 3
};

struct Mesh {
    std::vector<Vec3>                positions;
    std::vector<Vec3>                normals;
    std::vector<Vec2>                texcoords;
    std::vector<Group>               groups;
    std::map<std::string, Material>  materials;
};

// =============================================================================
// ESTADO GLOBAL (simples, sem singleton, suficiente pro teste)
// =============================================================================

static Mesh   g_stadiumMesh;
static Mesh   g_playerMeshes[8];
static int    g_winW = 1280;
static int    g_winH = 800;

// Câmera FPS-style: posição + ângulos yaw/pitch.
// Os jogadores têm cerca de 1,87 m. A posição inicial fica baixa o bastante
// para distinguir os uniformes e afastada o bastante para ver as duas metades
// do campo sem precisar reposicionar a câmera logo de início.
static Vec3   g_camPos    = {0.0f, 2.0f, 20.0f};
static float  g_yaw       = -90.0f;   // graus; -90 olha pro -Z
static float  g_pitch     = -8.0f;
static float  g_moveSpeed = 15.0f;    // unidades por segundo

// Estado do teclado (pra movimento contínuo)
static bool   g_keys[256]         = {false};
static bool   g_specialKeys[256]  = {false};

// Tempo do último frame, pra calcular delta
static int    g_lastMs = 0;

// Marcadores visuais dos refletores. As luzes em si ficam sempre ligadas para
// a cena assumir uma noite de jogo, sem alternância dia/noite.
static bool   g_showLightMarkers = true;

// Quatro torres/holofotes nos cantos do estádio high, apontando para o centro
// do campo. Estes pontos foram ajustados a partir dos vértices mais altos do
// stadium_high.obj, para a luz nascer visualmente dos refletores do modelo.
static Vec3   g_fieldCenter      = {-0.8f, 0.72f, 0.5f};
static Vec3   g_spotPositions[4] = {
    {-16.55f, 10.45f, -9.65f},
    { 14.95f, 10.45f, -9.65f},
    {-16.55f, 10.45f, 10.45f},
    { 14.95f, 10.45f, 10.45f}
};
// Jogadores no campo. O gramado do stadium_high.obj fica um pouco acima de
// y=0, então os pés são posicionados levemente acima dele. O campo é mais
// comprido em X; a linha do meio cruza Z e divide as metades em X.
struct PlayerInstance {
    int meshIndex;
    Vec3 position;
    float yawDeg;
};

static PlayerInstance g_players[8] = {
    // Time A: metade esquerda do campo (X menor), olhando para a linha do meio.
    {0, {-8.2f, 1.0f, -3.8f},  90.0f},
    {1, {-8.2f, 1.0f,  4.8f},  90.0f},
    {2, {-4.2f, 1.0f, -1.8f},  90.0f},
    {3, {-4.2f, 1.0f,  2.8f},  90.0f},

    // Time B: metade direita do campo (X maior), espelhado e olhando para o meio.
    {4, { 2.6f, 1.0f, -1.8f}, -90.0f},
    {5, { 2.6f, 1.0f,  2.8f}, -90.0f},
    {6, { 6.6f, 1.0f, -3.8f}, -90.0f},
    {7, { 6.6f, 1.0f,  4.8f}, -90.0f}
};

// =============================================================================
// HELPERS
// =============================================================================

inline float radians(float deg) { return deg * 3.14159265358979f / 180.0f; }

static Vec3 subtract(const Vec3& a, const Vec3& b) {
    return {a.x - b.x, a.y - b.y, a.z - b.z};
}

static Vec3 normalize(const Vec3& v) {
    float len = sqrtf(v.x * v.x + v.y * v.y + v.z * v.z);
    if (len <= 0.00001f) return {0.0f, -1.0f, 0.0f};
    return {v.x / len, v.y / len, v.z / len};
}

// Extrai o diretório de um path. Ex: "assets/models/stadium_high.obj" -> "assets/models"
static std::string dirname(const std::string& path) {
    size_t slash = path.find_last_of("/\\");
    if (slash == std::string::npos) return ".";
    return path.substr(0, slash);
}

static bool fileExists(const std::string& path) {
    std::ifstream f(path);
    return (bool)f;
}

// =============================================================================
// LOADER DE TEXTURA (PNG via stb_image)
// =============================================================================
//
// IMPORTANTE PRA COLOR RAMP / LOW-POLY:
//   - GL_NEAREST em MIN e MAG: preserva as faixas de cor nítidas. GL_LINEAR
//     borraria as bordas entre cores da paleta.
//   - GL_CLAMP_TO_EDGE: se uma UV cair em 0.999... por erro de float, NÃO
//     samplear do outro lado da textura.
//   - Sem mipmap: textura 64x64 não ganha nada com mipmap e pioraria sampling.
//
// stbi_set_flip_vertically_on_load(true) é importante: PNG tem origem
// top-left, OpenGL espera bottom-left. Sem o flip, a textura aparece de
// cabeça pra baixo.
// =============================================================================

static GLuint loadTexture(const std::string& path) {
    int w, h, n;
    stbi_set_flip_vertically_on_load(true);

    unsigned char* data = stbi_load(path.c_str(), &w, &h, &n, 0);
    if (!data) {
        std::cerr << "[textura] FALHA ao carregar: " << path
                  << " (" << stbi_failure_reason() << ")\n";
        return 0;
    }
    std::cout << "[textura] " << path << " " << w << "x" << h
              << " canais=" << n << "\n";

    GLuint id;
    glGenTextures(1, &id);
    glBindTexture(GL_TEXTURE_2D, id);

    GLenum fmt;
    switch (n) {
        case 1: fmt = GL_LUMINANCE; break;
        case 3: fmt = GL_RGB;       break;
        case 4: fmt = GL_RGBA;      break;
        default:
            std::cerr << "[textura] canais inesperados: " << n << "\n";
            stbi_image_free(data);
            return 0;
    }
    glTexImage2D(GL_TEXTURE_2D, 0, fmt, w, h, 0, fmt, GL_UNSIGNED_BYTE, data);

    // Filtros - essenciais pra color ramp
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S,     GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T,     GL_CLAMP_TO_EDGE);

    stbi_image_free(data);
    return id;
}

// =============================================================================
// PARSER DE .MTL
// =============================================================================
//
// Formato MTL básico:
//   newmtl <nome>
//   Ka r g b           - ambient
//   Kd r g b           - diffuse
//   Ks r g b           - specular
//   Ns <float>         - shininess exponent (no MTL vai 0..1000; GL aceita 0..128)
//   map_Kd <path>      - textura difusa (path relativo ao .mtl)
//
// Linhas começando com # são comentários. Ignoramos tudo que não conhecemos.
// =============================================================================

static void loadMTL(const std::string& path, Mesh& mesh) {
    std::ifstream f(path);
    if (!f) {
        std::cerr << "[mtl] FALHA ao abrir: " << path << "\n";
        return;
    }

    Material* cur = nullptr;
    std::string line;
    while (std::getline(f, line)) {
        std::istringstream iss(line);
        std::string kw;
        iss >> kw;
        if (kw.empty() || kw[0] == '#') continue;

        if (kw == "newmtl") {
            std::string name;
            iss >> name;
            Material m;
            m.name = name;
            mesh.materials[name] = m;
            cur = &mesh.materials[name];
        }
        else if (!cur) continue;
        else if (kw == "Ka") iss >> cur->Ka.x >> cur->Ka.y >> cur->Ka.z;
        else if (kw == "Kd") iss >> cur->Kd.x >> cur->Kd.y >> cur->Kd.z;
        else if (kw == "Ks") iss >> cur->Ks.x >> cur->Ks.y >> cur->Ks.z;
        else if (kw == "Ns") iss >> cur->Ns;
        else if (kw == "map_Kd") {
            // O resto da linha pode conter espaços em paths exóticos; aqui
            // assumimos que não tem.
            iss >> cur->map_Kd;
        }
    }
    std::cout << "[mtl] " << mesh.materials.size() << " materiais carregados de " << path << "\n";
}

// =============================================================================
// PARSER DE .OBJ
// =============================================================================
//
// Sintaxe relevante:
//   v   x y z            - vertex position
//   vn  x y z            - vertex normal
//   vt  u v              - vertex texcoord
//   f   v1/vt1/vn1 ...   - face (3+ vértices; vt e vn opcionais)
//   usemtl <nome>        - define material ativo
//   mtllib <arquivo>     - referência a um .mtl
//
// Índices no OBJ são 1-indexed. Convertemos pra 0-indexed.
// Faces com n>3 vértices (n-gons) são trianguladas via fan triangulation.
// Como exportamos com triangulate=True, esperamos só triângulos, mas o
// parser cobre o caso geral por segurança.
// =============================================================================

static void loadOBJ(const std::string& path, Mesh& mesh) {
    std::ifstream f(path);
    if (!f) {
        std::cerr << "[obj] FALHA ao abrir: " << path << "\n";
        std::exit(1);
    }

    const std::string baseDir = dirname(path);
    std::string currentMtl;   // material ativo (atualizado por 'usemtl')

    // Helper: garantir que existe um grupo com o material ativo,
    // criando um novo se o último grupo for de outro material.
    auto ensureGroup = [&]() -> Group& {
        if (mesh.groups.empty() || mesh.groups.back().materialName != currentMtl) {
            Group g; g.materialName = currentMtl;
            mesh.groups.push_back(g);
        }
        return mesh.groups.back();
    };

    std::string line;
    while (std::getline(f, line)) {
        if (line.empty() || line[0] == '#') continue;
        std::istringstream iss(line);
        std::string kw;
        iss >> kw;

        if (kw == "v") {
            Vec3 p; iss >> p.x >> p.y >> p.z;
            mesh.positions.push_back(p);
        }
        else if (kw == "vn") {
            Vec3 n; iss >> n.x >> n.y >> n.z;
            mesh.normals.push_back(n);
        }
        else if (kw == "vt") {
            Vec2 t; iss >> t.u >> t.v;
            mesh.texcoords.push_back(t);
        }
        else if (kw == "f") {
            // Parsear todos os vértices da face
            std::vector<FaceVertex> fv;
            std::string tok;
            while (iss >> tok) {
                FaceVertex x;
                // Trocar '/' por ' ' e ler com sub-stream
                // Formatos possíveis:
                //   v          (sem /)
                //   v/vt       (uma /)
                //   v//vn      (duas / consecutivas)
                //   v/vt/vn    (duas /)
                int slashes = (int)std::count(tok.begin(), tok.end(), '/');
                if (slashes == 0) {
                    x.v = std::stoi(tok) - 1;
                } else if (slashes == 1) {
                    size_t p = tok.find('/');
                    x.v  = std::stoi(tok.substr(0, p)) - 1;
                    x.vt = std::stoi(tok.substr(p + 1)) - 1;
                } else { // 2 slashes
                    size_t p1 = tok.find('/');
                    size_t p2 = tok.find('/', p1 + 1);
                    x.v = std::stoi(tok.substr(0, p1)) - 1;
                    std::string vts = tok.substr(p1 + 1, p2 - p1 - 1);
                    if (!vts.empty()) x.vt = std::stoi(vts) - 1;
                    x.vn = std::stoi(tok.substr(p2 + 1)) - 1;
                }
                fv.push_back(x);
            }
            if (fv.size() < 3) continue;

            // Fan triangulation: face de N vértices vira N-2 triângulos.
            Group& g = ensureGroup();
            for (size_t i = 1; i + 1 < fv.size(); i++) {
                g.vertices.push_back(fv[0]);
                g.vertices.push_back(fv[i]);
                g.vertices.push_back(fv[i + 1]);
            }
        }
        else if (kw == "usemtl") {
            iss >> currentMtl;
        }
        else if (kw == "mtllib") {
            std::string mtlFile;
            iss >> mtlFile;
            loadMTL(baseDir + "/" + mtlFile, mesh);
        }
        // 'g', 'o', 's' ignorados - não afetam render
    }

    std::cout << "[obj] " << path << ": "
              << mesh.positions.size() << " vertices, "
              << mesh.normals.size()   << " normais, "
              << mesh.texcoords.size() << " UVs, "
              << mesh.groups.size()    << " grupos\n";

    // Após carregar tudo, resolver as texturas. O map_Kd no MTL é relativo
    // ao próprio MTL, que está no mesmo diretório do OBJ - usamos baseDir.
    for (auto& kv : mesh.materials) {
        Material& m = kv.second;
        if (!m.map_Kd.empty()) {
            m.texID = loadTexture(baseDir + "/" + m.map_Kd);
        }
    }
}

// =============================================================================
// RENDER
// =============================================================================
//
// Estratégia: pra cada grupo de material, configura uma vez os parâmetros
// (textura, glMaterial) e desenha todos os triângulos do grupo em um único
// glBegin/glEnd. Isso minimiza chamadas de estado.
// =============================================================================

static void drawMesh(const Mesh& mesh) {
    for (const Group& g : mesh.groups) {
        // Material
        const Material* mat = nullptr;
        auto it = mesh.materials.find(g.materialName);
        if (it != mesh.materials.end()) mat = &it->second;

        if (mat) {
            // Convertendo Vec3 -> array com alpha
            // Diffuse próximo do material original: GL_MODULATE preserva a
            // textura, enquanto os holofotes fortes fazem a cena clarear.
            GLfloat kd[4] = {
                std::min(mat->Kd.x * 1.05f, 1.0f),
                std::min(mat->Kd.y * 1.05f, 1.0f),
                std::min(mat->Kd.z * 1.05f, 1.0f),
                1.0f
            };
            // Ambient moderado: a cena é noturna, mas estádio real tem bastante
            // luz rebatida internamente.
            GLfloat ka[4] = {
                std::min(mat->Ka.x * 0.24f, 0.24f),
                std::min(mat->Ka.y * 0.24f, 0.24f),
                std::min(mat->Ka.z * 0.28f, 0.28f),
                1.0f
            };
            // Specular sutil para assentos/metais pegarem brilho dos holofotes
            // sem transformar a textura em uma superfície branca.
            GLfloat ks[4] = {
                std::min(mat->Ks.x * 0.45f + 0.06f, 0.35f),
                std::min(mat->Ks.y * 0.45f + 0.06f, 0.35f),
                std::min(mat->Ks.z * 0.45f + 0.06f, 0.35f),
                1.0f
            };
            glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE,  kd);
            glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT,  ka);
            glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, ks);
            // GL_SHININESS espera 0..128 (o MTL pode chegar a 1000)
            glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS,
                        std::min(std::max(mat->Ns * 0.10f, 12.0f), 96.0f));

            if (mat->texID) {
                glEnable(GL_TEXTURE_2D);
                glBindTexture(GL_TEXTURE_2D, mat->texID);
            } else {
                glDisable(GL_TEXTURE_2D);
            }
        } else {
            glDisable(GL_TEXTURE_2D);
        }

        glBegin(GL_TRIANGLES);
        for (const FaceVertex& fv : g.vertices) {
            if (fv.vn >= 0 && fv.vn < (int)mesh.normals.size()) {
                const Vec3& n = mesh.normals[fv.vn];
                glNormal3f(n.x, n.y, n.z);
            }
            if (fv.vt >= 0 && fv.vt < (int)mesh.texcoords.size()) {
                const Vec2& t = mesh.texcoords[fv.vt];
                glTexCoord2f(t.u, t.v);
            }
            if (fv.v >= 0 && fv.v < (int)mesh.positions.size()) {
                const Vec3& p = mesh.positions[fv.v];
                glVertex3f(p.x, p.y, p.z);
            }
        }
        glEnd();
    }
}

static void drawLightMarkers() {
    if (!g_showLightMarkers) return;

    // Marcadores são apenas debug visual: desenhamos sem iluminação/textura para
    // aparecerem sempre como pequenas esferas emissivas nos cantos do estádio.
    glDisable(GL_TEXTURE_2D);
    glDisable(GL_LIGHTING);

    glColor3f(1.0f, 0.88f, 0.35f);
    for (int i = 0; i < 4; ++i) {
        glPushMatrix();
        glTranslatef(g_spotPositions[i].x, g_spotPositions[i].y, g_spotPositions[i].z);
        glutSolidSphere(0.45, 16, 12);
        glPopMatrix();
    }

    glColor3f(1.0f, 1.0f, 1.0f);
    glEnable(GL_LIGHTING);
}

static void drawSpotlightBeams() {
    // O fixed pipeline ilumina superfícies, mas não desenha o volume de luz.
    // Estes feixes translúcidos são uma ajuda visual para mostrar que a luz sai
    // dos refletores e abre em direção ao campo.
    glDisable(GL_TEXTURE_2D);
    glDisable(GL_LIGHTING);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    glDepthMask(GL_FALSE);

    const float radius = 7.2f;
    for (int i = 0; i < 4; ++i) {
        const Vec3& p = g_spotPositions[i];

        glBegin(GL_TRIANGLE_FAN);
        glColor4f(1.0f, 0.92f, 0.68f, 0.18f);
        glVertex3f(p.x, p.y, p.z);
        glColor4f(1.0f, 0.92f, 0.68f, 0.015f);
        for (int s = 0; s <= 18; ++s) {
            float a = (2.0f * 3.14159265358979f * s) / 18.0f;
            glVertex3f(g_fieldCenter.x + cosf(a) * radius,
                       g_fieldCenter.y + 0.10f,
                       g_fieldCenter.z + sinf(a) * radius);
        }
        glEnd();
    }

    glDepthMask(GL_TRUE);
    glDisable(GL_BLEND);
    glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
    glEnable(GL_LIGHTING);
}

// =============================================================================
// CÂMERA + INPUT
// =============================================================================

static void computeForwardRight(Vec3& fwd, Vec3& right) {
    float cy = cosf(radians(g_yaw));
    float sy = sinf(radians(g_yaw));
    float cp = cosf(radians(g_pitch));
    float sp = sinf(radians(g_pitch));
    fwd   = { cy * cp, sp, sy * cp };
    right = { -sy,     0,  cy      };  // right = fwd x up (com up=+Y)
}

static void resetCamera() {
    g_camPos    = {0.0f, 2.0f, 20.0f};
    g_yaw       = -90.0f;
    g_pitch     = -8.0f;
    g_moveSpeed = 15.0f;
}

static void keyboardDown(unsigned char key, int, int) {
    g_keys[key] = true;
    if (key == 27 /* ESC */) std::exit(0);
    if (key == 'r' || key == 'R') resetCamera();
    if (key == '+' || key == '=') g_moveSpeed *= 1.25f;
    if (key == '-' || key == '_') g_moveSpeed /= 1.25f;
    if (key == 'l' || key == 'L') g_showLightMarkers = !g_showLightMarkers;
}
static void keyboardUp(unsigned char key, int, int)   { g_keys[key] = false; }
static void specialDown(int key, int, int)            { g_specialKeys[key] = true; }
static void specialUp(int key, int, int)              { g_specialKeys[key] = false; }

static void updateCamera(float dt) {
    Vec3 fwd, right;
    computeForwardRight(fwd, right);
    float s = g_moveSpeed * dt;
    const float rotSpeed = 90.0f * dt; // graus por segundo

    if (g_keys['w'] || g_keys['W']) { g_camPos.x += fwd.x * s; g_camPos.y += fwd.y * s; g_camPos.z += fwd.z * s; }
    if (g_keys['s'] || g_keys['S']) { g_camPos.x -= fwd.x * s; g_camPos.y -= fwd.y * s; g_camPos.z -= fwd.z * s; }
    if (g_keys['a'] || g_keys['A']) { g_camPos.x -= right.x * s; g_camPos.z -= right.z * s; }
    if (g_keys['d'] || g_keys['D']) { g_camPos.x += right.x * s; g_camPos.z += right.z * s; }
    if (g_keys['q'] || g_keys['Q']) g_camPos.y -= s;
    if (g_keys['e'] || g_keys['E']) g_camPos.y += s;

    if (g_specialKeys[GLUT_KEY_LEFT])  g_yaw   -= rotSpeed;
    if (g_specialKeys[GLUT_KEY_RIGHT]) g_yaw   += rotSpeed;
    if (g_specialKeys[GLUT_KEY_UP])    g_pitch += rotSpeed;
    if (g_specialKeys[GLUT_KEY_DOWN])  g_pitch -= rotSpeed;

    if (g_pitch >  89.0f) g_pitch =  89.0f;
    if (g_pitch < -89.0f) g_pitch = -89.0f;
}

// =============================================================================
// CALLBACKS GLUT
// =============================================================================

static void reshape(int w, int h) {
    g_winW = w;
    g_winH = (h > 0) ? h : 1;
    glViewport(0, 0, g_winW, g_winH);
}

static void configureLighting() {
    // Luz ambiente global: é a parcela mínima que ilumina tudo igualmente.
    // Para uma noite de estádio real, ela não pode ser preta: há muita luz
    // rebatida no gramado, arquibancadas e cobertura.
    GLfloat globalNight[4] = {0.145f, 0.150f, 0.165f, 1.0f};
    glLightModelfv(GL_LIGHT_MODEL_AMBIENT, globalNight);

    // GL_LIGHT0 como luz direcional: w=0 em GL_POSITION significa que a luz
    // vem de uma direção infinita. Como queremos que a cena pareça iluminada
    // pelos refletores do estádio, ela fica desativada; o preenchimento vem do
    // ambiente global acima.
    glDisable(GL_LIGHT0);
    GLfloat dirPos[4]  = {-0.25f, 0.80f, 0.20f, 0.0f};
    GLfloat dirAmb[4]  = { 0.000f, 0.000f, 0.000f, 1.0f};
    GLfloat dirDif[4]  = { 0.000f, 0.000f, 0.000f, 1.0f};
    GLfloat dirSpec[4] = { 0.000f, 0.000f, 0.000f, 1.0f};
    glLightfv(GL_LIGHT0, GL_POSITION, dirPos);
    glLightfv(GL_LIGHT0, GL_AMBIENT,  dirAmb);
    glLightfv(GL_LIGHT0, GL_DIFFUSE,  dirDif);
    glLightfv(GL_LIGHT0, GL_SPECULAR, dirSpec);

    // GL_LIGHT1..GL_LIGHT4 como holofotes: cada luz tem posição real (w=1),
    // direção para o centro do campo, cone controlado por CUTOFF/EXPONENT e
    // atenuação para perder força com a distância.
    const GLenum ids[4] = {GL_LIGHT1, GL_LIGHT2, GL_LIGHT3, GL_LIGHT4};
    for (int i = 0; i < 4; ++i) {
        glEnable(ids[i]);

        Vec3 dir = normalize(subtract(g_fieldCenter, g_spotPositions[i]));
        GLfloat pos[4] = {g_spotPositions[i].x, g_spotPositions[i].y, g_spotPositions[i].z, 1.0f};
        GLfloat spotDir[3] = {dir.x, dir.y, dir.z};
        GLfloat amb[4]  = {0.028f, 0.026f, 0.020f, 1.0f};
        GLfloat dif[4]  = {1.65f, 1.55f, 1.30f, 1.0f};
        GLfloat spec[4] = {0.95f, 0.88f, 0.72f, 1.0f};

        glLightfv(ids[i], GL_POSITION, pos);
        glLightfv(ids[i], GL_SPOT_DIRECTION, spotDir);
        glLightfv(ids[i], GL_AMBIENT,  amb);
        glLightfv(ids[i], GL_DIFFUSE,  dif);
        glLightfv(ids[i], GL_SPECULAR, spec);
        glLightf(ids[i], GL_SPOT_CUTOFF,   54.0f);
        glLightf(ids[i], GL_SPOT_EXPONENT, 5.0f);
        glLightf(ids[i], GL_CONSTANT_ATTENUATION,  1.0f);
        glLightf(ids[i], GL_LINEAR_ATTENUATION,    0.004f);
        glLightf(ids[i], GL_QUADRATIC_ATTENUATION, 0.00016f);
    }
}

static void drawSceneObjects() {
    drawMesh(g_stadiumMesh);

    for (const PlayerInstance& player : g_players) {
        glPushMatrix();
        glTranslatef(player.position.x, player.position.y, player.position.z);
        glRotatef(player.yawDeg, 0.0f, 1.0f, 0.0f);
        drawMesh(g_playerMeshes[player.meshIndex]);
        glPopMatrix();
    }
}

static void display() {
    // Céu noturno fixo: escuro, mas levemente azulado.
    glClearColor(0.020f, 0.030f, 0.070f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    // PROJECTION
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    gluPerspective(60.0,                                // FOV vertical
                   (double)g_winW / (double)g_winH,     // aspect
                   0.1, 500.0);                          // near / far

    // MODELVIEW (câmera)
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    Vec3 fwd, right;
    computeForwardRight(fwd, right);
    gluLookAt(g_camPos.x, g_camPos.y, g_camPos.z,
              g_camPos.x + fwd.x, g_camPos.y + fwd.y, g_camPos.z + fwd.z,
              0.0, 1.0, 0.0);

    // Luzes são posicionadas depois da câmera, então ficam em coordenadas de
    // mundo e não "grudam" no observador.
    configureLighting();

    drawSceneObjects();
    drawSpotlightBeams();
    drawLightMarkers();

    glutSwapBuffers();
}

static void idle() {
    int now = glutGet(GLUT_ELAPSED_TIME);
    float dt = (g_lastMs == 0) ? 0.016f : (now - g_lastMs) / 1000.0f;
    g_lastMs = now;
    if (dt > 0.1f) dt = 0.1f; // clamp pra evitar saltos quando minimiza

    updateCamera(dt);
    glutPostRedisplay();
}

// =============================================================================
// SETUP DE GL E LUZ
// =============================================================================

static void initGL() {
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);

    glEnable(GL_LIGHTING);

    // Modelo de iluminação do fixed pipeline. A intensidade global e as
    // posições das luzes são atualizadas em configureLighting(), depois que a
    // câmera já foi aplicada.
    glLightModeli(GL_LIGHT_MODEL_TWO_SIDE, GL_TRUE);
    glLightModeli(GL_LIGHT_MODEL_LOCAL_VIEWER, GL_TRUE);

    // Modulação de textura por iluminação (default)
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);

    // Normalizar normais (importante se houver escala não-uniforme)
    glEnable(GL_NORMALIZE);

    // Backface culling: pode quebrar se o modelo tiver normais invertidas em
    // algum lugar. Deixei desligado pra ver tudo no primeiro teste; depois que
    // confirmar que o modelo aparece OK, ligue pra ganhar performance:
    // glEnable(GL_CULL_FACE); glCullFace(GL_BACK);

    glShadeModel(GL_SMOOTH);
}

// =============================================================================
// MAIN
// =============================================================================

int main(int argc, char** argv) {
    glutInit(&argc, argv);
    glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGBA | GLUT_DEPTH);
    glutInitWindowSize(g_winW, g_winH);
    glutCreateWindow("StadiumGL - Pipeline Test");

    initGL();

    // Carregar os modelos. Paths relativos ao CWD (raiz do projeto).
    loadOBJ("assets/models/stadium_high.obj", g_stadiumMesh);
    const char* playerPaths[8] = {
        "assets/models/players/teamA_player_01.obj",
        "assets/models/players/teamA_player_02.obj",
        "assets/models/players/teamA_player_03.obj",
        "assets/models/players/teamA_player_04.obj",
        "assets/models/players/teamB_player_01.obj",
        "assets/models/players/teamB_player_02.obj",
        "assets/models/players/teamB_player_03.obj",
        "assets/models/players/teamB_player_04.obj"
    };
    for (int i = 0; i < 8; ++i) {
        if (fileExists(playerPaths[i])) {
            loadOBJ(playerPaths[i], g_playerMeshes[i]);
        } else {
            std::cout << "[obj] " << playerPaths[i]
                      << " nao encontrado; seguindo sem este jogador.\n";
        }
    }

    glutDisplayFunc(display);
    glutReshapeFunc(reshape);
    glutKeyboardFunc(keyboardDown);
    glutKeyboardUpFunc(keyboardUp);
    glutSpecialFunc(specialDown);
    glutSpecialUpFunc(specialUp);
    glutIdleFunc(idle);

    std::cout << "\nControles:\n"
              << "  WASD   mover (frente/lados)\n"
              << "  Q/E    descer/subir\n"
              << "  setas  olhar\n"
              << "  +/-    velocidade\n"
              << "  R      reset\n"
              << "  L      liga/desliga marcadores dos holofotes\n"
              << "  ESC    sair\n\n";

    glutMainLoop();
    return 0;
}
