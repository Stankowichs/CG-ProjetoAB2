extends SceneTree

# Ferramenta de build (não roda no jogo).
#
# Gera res://anims/hulk_keeper_anims.res a partir dos FBX de goleiro do Mixamo
# em anims/goalkeeper_mixamo/. Mesmo tratamento do bake_anims.gd: remove as
# tracks de posição e a rotação do quadril (root motion/orientação global — quem
# orienta o goleiro é o nó na cena) e reescreve o prefixo das tracks pro
# esqueleto do hulk (HulkArmature/Skeleton3D).
#
# Também mede a inclinação lateral (eixo X local) de cada mergulho, pra o código
# escolher o clipe certo conforme o lado da bola.
#
# Rode após baixar/atualizar os FBX:
#   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/bake_keeper_anims.gd

const OUT_PATH := "res://anims/hulk_keeper_anims.res"

const CLIPS := {
	"Idle":  "res://anims/goalkeeper_mixamo/Goalkeeper Idle.fbx",
	"DiveA": "res://anims/goalkeeper_mixamo/Goalkeeper Diving Save.fbx",
	"DiveB": "res://anims/goalkeeper_mixamo/Goalkeeper Diving Save-2.fbx",
	"Throw": "res://anims/goalkeeper_mixamo/Goalkeeper Overhand Throw.fbx",
}

const LOOPING := ["Idle"]

const SRC_PREFIX := "Skeleton3D:"
const DST_PREFIX := "HulkArmature/Skeleton3D:"

func _init() -> void:
	var lib := AnimationLibrary.new()

	for clip_name in CLIPS:
		var path: String = CLIPS[clip_name]
		var ps: PackedScene = load(path)
		if ps == null:
			push_error("Falha ao carregar " + path)
			continue
		var scene := ps.instantiate()
		var ap: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
		if ap == null or ap.get_animation_list().is_empty():
			push_error("Sem animação em " + path)
			scene.free()
			continue

		var anim: Animation = ap.get_animation(ap.get_animation_list()[0]).duplicate(true)

		# mede inclinação lateral do quadril (antes de remover a track de posição)
		var hips_start_x := 0.0
		var hips_peak := 0.0
		for i in anim.get_track_count():
			if anim.track_get_type(i) == Animation.TYPE_POSITION_3D and String(anim.track_get_path(i)).ends_with(":mixamorig_Hips"):
				if anim.track_get_key_count(i) > 0:
					hips_start_x = (anim.track_get_key_value(i, 0) as Vector3).x
					for k in anim.track_get_key_count(i):
						var dx := (anim.track_get_key_value(i, k) as Vector3).x - hips_start_x
						if absf(dx) > absf(hips_peak):
							hips_peak = dx

		for i in range(anim.get_track_count() - 1, -1, -1):
			var p := String(anim.track_get_path(i))
			var is_hips := p.ends_with(":mixamorig_Hips")
			if (
				anim.track_get_type(i) == Animation.TYPE_POSITION_3D
				or (is_hips and anim.track_get_type(i) == Animation.TYPE_ROTATION_3D)
			):
				anim.remove_track(i)
				continue
			if p.begins_with(SRC_PREFIX):
				anim.track_set_path(i, NodePath(DST_PREFIX + p.substr(SRC_PREFIX.length())))

		anim.loop_mode = Animation.LOOP_LINEAR if clip_name in LOOPING else Animation.LOOP_NONE
		lib.add_animation(clip_name, anim)
		print("OK  %-6s tracks=%d len=%.2f loop=%s hips_lean_x=%.1f" % [clip_name, anim.get_track_count(), anim.length, clip_name in LOOPING, hips_peak])
		scene.free()

	var err := ResourceSaver.save(lib, OUT_PATH)
	print("save -> ", OUT_PATH, "  err=", err)
	quit()
