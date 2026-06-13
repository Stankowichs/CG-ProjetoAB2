"""
Headless retarget script.
Run with: blender --background --python scripts/blender/retarget_players.py

For each player_*.glb in models/:
- Loads its CC_Base armature + meshes
- Imports each anim FBX from anims/
- Builds bone constraints (Copy Rotation, Copy Location for root) from CC_Base bones
  pointing to mixamorig bones in the temp armature
- Bakes the constraint into a new action on the CC_Base armature
- Removes temp anim armature
- Repeats for all 12 anim FBXes
- Exports as <name>_anim.glb (or overwrites original)
"""
import bpy
import os

PROJECT = "/Users/hugostankowich/Projects/CG-ProjetoAB2"
ANIMS_DIR = f"{PROJECT}/anims"
MODELS_DIR = f"{PROJECT}/models"

# CC_Base bone (target) -> Mixamo bone (source). Mapped to friendly Player.gd anim names.
BONE_MAP = {
    'CC_Base_Hip_02':                'mixamorig:Hips',
    'CC_Base_Waist_033':             'mixamorig:Spine',
    'CC_Base_Spine01_034':           'mixamorig:Spine1',
    'CC_Base_Spine02_035':           'mixamorig:Spine2',
    'CC_Base_NeckTwist01_036':       'mixamorig:Neck',
    'CC_Base_Head_038':              'mixamorig:Head',
    'CC_Base_L_Clavicle_049':        'mixamorig:LeftShoulder',
    'CC_Base_L_Upperarm_050':        'mixamorig:LeftArm',
    'CC_Base_L_Forearm_051':         'mixamorig:LeftForeArm',
    'CC_Base_L_Hand_055':            'mixamorig:LeftHand',
    'CC_Base_R_Clavicle_073':        'mixamorig:RightShoulder',
    'CC_Base_R_Upperarm_074':        'mixamorig:RightArm',
    'CC_Base_R_Forearm_077':         'mixamorig:RightForeArm',
    'CC_Base_R_Hand_081':            'mixamorig:RightHand',
    'CC_Base_L_Thigh_04':            'mixamorig:LeftUpLeg',
    'CC_Base_L_Calf_05':             'mixamorig:LeftLeg',
    'CC_Base_L_Foot_06':             'mixamorig:LeftFoot',
    'CC_Base_L_ToeBase_08':          'mixamorig:LeftToeBase',
    'CC_Base_R_Thigh_018':           'mixamorig:RightUpLeg',
    'CC_Base_R_Calf_021':            'mixamorig:RightLeg',
    'CC_Base_R_Foot_022':            'mixamorig:RightFoot',
    'CC_Base_R_ToeBase_023':         'mixamorig:RightToeBase',
}

ANIM_FILES = [
    ("Offensive Idle.fbx",       "Idle",            True),   # loop
    ("Jog Forward.fbx",          "Running",         True),
    ("Jog Forward Diagonal.fbx", "RunningDiagonal", True),
    ("Kick Soccerball.fbx",      "Kick",            False),
    ("Soccer Penalty Kick.fbx",  "PenaltyKick",     False),
    ("Soccer Pass.fbx",          "Pass",            False),
    ("Receive Soccerball.fbx",   "Receive",         False),
    ("Strike Foward Jog.fbx",    "RunningKick",     False),
    ("Soccer Tackle.fbx",        "Tackle",          False),
    ("Soccer Trip.fbx",          "Trip",            False),
    ("Soccer Header.fbx",        "Header",          False),
    ("Throw In.fbx",             "ThrowIn",         False),
]

PLAYERS = ["player.glb", "player_red.glb", "player_yellow.glb"]


def full_reset():
    bpy.ops.wm.read_homefile(use_empty=True)
    # Ensure context
    bpy.ops.mesh.primitive_cube_add()
    bpy.ops.object.delete()


def find_armature():
    for o in bpy.data.objects:
        if o.type == 'ARMATURE':
            return o
    return None


def import_anim_get_armature(fbx_path):
    before = set(o.name for o in bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=fbx_path, automatic_bone_orientation=True)
    new = [o for o in bpy.data.objects if o.name not in before]
    return new, [o for o in new if o.type == 'ARMATURE'][0]


def retarget_one_animation(target_arm, source_arm, target_action_name, anim_frame_range):
    """
    Build Copy Rotation + Copy Location constraints on target bones,
    then bake the animation as a new action on target_arm.
    """
    # Ensure pose mode + clear existing constraints on mapped bones
    bpy.context.view_layer.objects.active = target_arm
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.pose.select_all(action='DESELECT')

    # Add constraints
    for tgt_bone_name, src_bone_name in BONE_MAP.items():
        if tgt_bone_name not in target_arm.pose.bones:
            continue
        if src_bone_name not in source_arm.pose.bones:
            continue
        pb = target_arm.pose.bones[tgt_bone_name]
        # Clear old constraints
        for c in list(pb.constraints):
            pb.constraints.remove(c)
        # Copy Rotation in WORLD space (handles rest-pose orientation differences)
        cr = pb.constraints.new('COPY_ROTATION')
        cr.target = source_arm
        cr.subtarget = src_bone_name
        cr.target_space = 'WORLD'
        cr.owner_space = 'WORLD'
        # For the root (Hips), also copy location so the body moves with the anim
        if tgt_bone_name == 'CC_Base_Hip_02':
            cl = pb.constraints.new('COPY_LOCATION')
            cl.target = source_arm
            cl.subtarget = src_bone_name
            cl.target_space = 'WORLD'
            cl.owner_space = 'WORLD'

    # Bake action
    f_start, f_end = int(anim_frame_range[0]), int(anim_frame_range[1])
    bpy.context.scene.frame_start = f_start
    bpy.context.scene.frame_end = f_end

    # Select bones to bake (only the mapped ones)
    for bone_name in BONE_MAP.keys():
        if bone_name in target_arm.pose.bones:
            pb = target_arm.pose.bones[bone_name]
            pb.bone.select = True

    bpy.ops.nla.bake(
        frame_start=f_start, frame_end=f_end,
        only_selected=True,
        visual_keying=True,
        clear_constraints=True,
        clear_parents=False,
        use_current_action=False,
        bake_types={'POSE'},
    )

    # Rename the baked action
    new_action = target_arm.animation_data.action
    if new_action:
        new_action.name = target_action_name
        new_action.use_fake_user = True

    bpy.ops.object.mode_set(mode='OBJECT')


def process_player(player_path):
    print(f"\n{'='*60}\nProcessing {player_path}\n{'='*60}")
    full_reset()

    # 1) Import player glb
    bpy.ops.import_scene.gltf(filepath=player_path)
    target_arm = find_armature()
    if target_arm is None:
        print(f"  ERROR: no armature in {player_path}")
        return
    print(f"  Target armature: {target_arm.name}, bones: {len(target_arm.data.bones)}")

    # Remove any existing animations on the target (clean state)
    if target_arm.animation_data:
        for t in list(target_arm.animation_data.nla_tracks):
            target_arm.animation_data.nla_tracks.remove(t)
        target_arm.animation_data.action = None

    # Drop old animations from the file
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)

    # 2) For each animation FBX, import + retarget + cleanup
    for fbx_name, action_name, is_loop in ANIM_FILES:
        fbx_path = os.path.join(ANIMS_DIR, fbx_name)
        if not os.path.exists(fbx_path):
            print(f"  SKIP: missing {fbx_name}")
            continue

        # Import (creates temp source armature + temp action)
        new_objs, source_arm = import_anim_get_armature(fbx_path)
        # Find the imported action
        src_action = None
        for ad in [source_arm.animation_data]:
            if ad and ad.action:
                src_action = ad.action
                break
        if src_action is None:
            # last imported action
            for a in bpy.data.actions:
                if a.users > 0 and a not in (None,):
                    src_action = a
        if src_action is None:
            print(f"  SKIP {fbx_name}: no source action")
            continue

        # Retarget
        try:
            retarget_one_animation(target_arm, source_arm, action_name, src_action.frame_range)
            print(f"  OK  {action_name} ({int(src_action.frame_range[0])}-{int(src_action.frame_range[1])})")
        except Exception as e:
            print(f"  FAIL {action_name}: {e}")

        # Cleanup temp objects + temp action
        bpy.ops.object.select_all(action='DESELECT')
        for o in new_objs:
            if o.name in bpy.data.objects:
                bpy.data.objects[o.name].select_set(True)
        bpy.ops.object.delete(use_global=False)
        if src_action.name in bpy.data.actions:
            try:
                bpy.data.actions.remove(src_action)
            except:
                pass

    # 3) Push all actions to NLA muted
    if target_arm.animation_data is None:
        target_arm.animation_data_create()
    for a in bpy.data.actions:
        track = target_arm.animation_data.nla_tracks.new()
        track.name = a.name
        track.strips.new(a.name, int(a.frame_range[0]), a)
        track.mute = True
    if "Idle" in bpy.data.actions:
        target_arm.animation_data.action = bpy.data.actions["Idle"]

    # 4) Export GLB
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = target_arm
    bpy.ops.export_scene.gltf(
        filepath=player_path,
        export_format='GLB',
        use_selection=True,
        export_animations=True,
        export_animation_mode='ACTIONS',
        export_skins=True,
        export_apply=False,
        export_yup=True,
    )
    size = os.path.getsize(player_path)
    print(f"  Exported {player_path} ({size//1024} KB)")


if __name__ == "__main__":
    for p in PLAYERS:
        process_player(os.path.join(MODELS_DIR, p))
    print("\nALL DONE")
