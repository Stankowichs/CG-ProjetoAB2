"""
Gera a torcida (models/crowd.glb) a partir da geometria REAL do stadium.glb.

Como usar (no Blender, com o Blender MCP ou rodando no Text Editor):
    Basta executar este arquivo. Ele:
      1. Importa models/stadium.glb (limpando a cena).
      2. Isola a superfície de assento: usa só os objetos cujo topo (altura) fica
         entre ~2.5 e ~40 (exclui gramado, fachada e telhado), depois mantém só as
         faces voltadas pra cima, na faixa de altura dos tiers, dentro do anel da
         arquibancada (fora da elipse do gramado e dentro da elipse externa).
      3. Espalha torcedores área-ponderados nessa superfície: mistura de "blocos de
         cor" (speckle) e bonecos low-poly (corpo + cabeça), em pé, virados pro
         campo, com cores por vértice e leve viés de torcida por gol.
      4. Exporta models/crowd.glb (Y-up, com COLOR_0), alinhado ao estádio.

Ajuste os parâmetros no bloco CONFIG. Coordenadas: mundo do Blender (Z-up); o
centro do bowl é ~(-1.5, 0). O export Y-up faz o crowd.glb cair alinhado ao
stadium.glb quando ambos são importados no Godot.
"""
import bpy, bmesh, mathutils, random, bisect, os

# ----------------------------- CONFIG -----------------------------
PROJECT = "/Users/hugostankowich/Projects/CG-ProjetoAB2"
STADIUM = os.path.join(PROJECT, "models/stadium.glb")
OUT     = os.path.join(PROJECT, "models/crowd.glb")

CENTER   = mathutils.Vector((-1.5, 0.0, 0.0))  # centro do bowl (X, Y, Z-up)
SEAT_ZMAX_MIN, SEAT_ZMAX_MAX = 2.5, 40.0       # objetos de assento por altura do topo
PITCH_PX, PITCH_PY = 53.0, 34.0                # elipse do gramado (exclui o campo)
OUTER_PX, OUTER_PY = 97.0, 84.0                # elipse externa da arquibancada
ZMIN, ZMAX = 2.5, 46.0                         # faixa de altura das faces de assento
NZ_MIN = 0.30                                  # face precisa olhar pra cima

N_SPECTATORS = 16000      # estádio lotado
SPECKLE_RATIO = 0.60      # 60% blocos de cor, 40% bonecos low-poly
SEED = 1234

HOME = [(0.95,0.81,0.40),(0.17,0.57,0.28),(0.93,0.93,0.93),(0.18,0.42,0.74)]  # amarelo/verde/branco/azul
AWAY = [(0.79,0.23,0.21),(0.94,0.95,0.97),(0.13,0.13,0.15),(0.73,0.19,0.19)]  # vermelho/branco/preto
SKIN = [(0.86,0.66,0.52),(0.69,0.49,0.36),(0.55,0.39,0.28),(0.94,0.78,0.66)]
UP = mathutils.Vector((0,0,1))
# ------------------------------------------------------------------


def clean_scene():
    for o in list(bpy.data.objects):
        if o.type not in {'CAMERA', 'LIGHT'}:
            bpy.data.objects.remove(o, do_unlink=True)


def import_stadium():
    bpy.ops.import_scene.gltf(filepath=STADIUM)


def build_seating_surface():
    # objetos de assento por altura do topo (mundo)
    seat = []
    for o in bpy.data.objects:
        if o.type != 'MESH' or not o.name.startswith("Object_"):
            continue
        mw = o.matrix_world; zmx = -1e9
        vs = o.data.vertices; step = max(1, len(vs)//200)
        for i in range(0, len(vs), step):
            zmx = max(zmx, (mw @ vs[i].co).z)
        if SEAT_ZMAX_MIN < zmx < SEAT_ZMAX_MAX:
            seat.append(o)

    bpy.ops.object.select_all(action='DESELECT')
    for o in seat:
        o.select_set(True)
    bpy.context.view_layer.objects.active = seat[0]
    bpy.ops.object.duplicate()
    dups = list(bpy.context.selected_objects)
    bpy.context.view_layer.objects.active = dups[0]
    bpy.ops.object.join()
    surf = bpy.context.view_layer.objects.active
    surf.name = "SeatingSurface"
    if surf.data.users > 1:
        surf.data = surf.data.copy()
    surf.data.transform(surf.matrix_world)              # assa a matriz na malha
    surf.matrix_world = mathutils.Matrix.Identity(4)

    me = surf.data
    bm = bmesh.new(); bm.from_mesh(me); bm.normal_update()
    dele = []
    for f in bm.faces:
        c = f.calc_center_median(); nz = abs(f.normal.z)
        keep = nz > NZ_MIN and ZMIN <= c.z <= ZMAX
        if keep:
            dx = c.x-CENTER.x; dy = c.y-CENTER.y
            inside_pitch = (dx/PITCH_PX)**2 + (dy/PITCH_PY)**2 < 1.0
            outside_bowl = (dx/OUTER_PX)**2 + (dy/OUTER_PY)**2 > 1.0
            if inside_pitch or outside_bowl:
                keep = False
        if not keep:
            dele.append(f)
    bmesh.ops.delete(bm, geom=dele, context='FACES')
    bm.to_mesh(me); bm.free()
    return surf


def scatter(surf):
    random.seed(SEED)
    me = surf.data
    src = [v.co.copy() for v in me.vertices]
    tris = []; cum = []; total = 0.0
    for p in me.polygons:
        vi = list(p.vertices)
        for k in range(1, len(vi)-1):
            a, b, c = src[vi[0]], src[vi[k]], src[vi[k+1]]
            ar = (b-a).cross(c-a).length*0.5
            if ar <= 0:
                continue
            total += ar; tris.append((a, b, c)); cum.append(total)

    V = []; F = []; C = []

    def add_box(center, right, fwd, up, sx, sy, sz, col):
        o = len(V); rx = right*sx*0.5; fy = fwd*sy*0.5; uz = up*sz
        cs = [center-rx-fy, center+rx-fy, center+rx+fy, center-rx+fy,
              center-rx-fy+uz, center+rx-fy+uz, center+rx+fy+uz, center-rx+fy+uz]
        for c in cs:
            V.append((c.x, c.y, c.z)); C.append(col)
        for a, b, c, d in [(0,1,2,3),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:
            F.append((o+a, o+b, o+c, o+d))

    for _ in range(N_SPECTATORS):
        r = random.random()*total
        a, b, c = tris[bisect.bisect_left(cum, r)]
        u = random.random(); v = random.random()
        if u+v > 1:
            u, v = 1-u, 1-v
        P = a + (b-a)*u + (c-a)*v
        if P.z < 2.0:
            continue
        fwd = (CENTER-P); fwd.z = 0
        if fwd.length < 0.01:
            continue
        fwd.normalize(); right = fwd.cross(UP).normalized(); P = P + UP*0.05
        bias = 0.5 - max(-1, min(1, (P.x-CENTER.x)/90.0))*0.5
        pal = HOME if random.random() < bias else AWAY
        col = random.choice(pal); j = random.uniform(-0.04, 0.04)
        col = (min(1, max(0, col[0]+j)), min(1, max(0, col[1]+j)), min(1, max(0, col[2]+j)))
        if random.random() < SPECKLE_RATIO:
            add_box(P, right, fwd, UP, random.uniform(0.42,0.55), random.uniform(0.42,0.55), random.uniform(0.45,0.62), col)
        else:
            bh = random.uniform(0.85, 1.05)
            add_box(P, right, fwd, UP, 0.42, 0.34, bh, col)
            add_box(P+UP*bh, right, fwd, UP, 0.26, 0.24, 0.26, random.choice(SKIN))

    old = bpy.data.objects.get("Crowd")
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    cm = bpy.data.meshes.new("CrowdMesh"); cm.from_pydata(V, [], F); cm.update()
    ca = cm.color_attributes.new(name="Col", type='FLOAT_COLOR', domain='POINT')
    for i, col in enumerate(C):
        ca.data[i].color = (col[0], col[1], col[2], 1.0)
    crowd = bpy.data.objects.new("Crowd", cm)
    bpy.context.scene.collection.objects.link(crowd)
    return crowd


def export(crowd):
    bpy.ops.object.select_all(action='DESELECT')
    crowd.select_set(True); bpy.context.view_layer.objects.active = crowd
    bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True,
                              export_apply=True, export_cameras=False, export_lights=False,
                              export_yup=True, export_attributes=True)
    print("crowd exportado:", OUT, os.path.getsize(OUT), "bytes")


def main():
    clean_scene()
    import_stadium()
    surf = build_seating_surface()
    crowd = scatter(surf)
    bpy.data.objects.remove(surf, do_unlink=True)
    # esconde o estádio (só a torcida vai pro export por seleção)
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.name.startswith("Object_"):
            o.hide_set(True)
    export(crowd)


if __name__ == "__main__":
    main()
