extends SceneTree

# Ferramenta de build (não roda no jogo).
#
# Gera res://anims/ronaldo_anims.res a partir dos FBX do Mixamo em
# anims/ronaldo_mixamo/. As animações embutidas no ronaldo.glb perderam a
# rotação dos ossos na exportação (só a Running sobreviveu); os FBX-fonte estão
# íntegros, então reaproveitamos os clipes deles.
#
# O que faz: copia cada clipe, remove as tracks de posição/rotação do quadril
# (root motion/orientação global — quem move e orienta o jogador é o
# CharacterBody3D) e reescreve o prefixo das tracks pro esqueleto do ronaldo.glb.
#
# Rode após baixar/atualizar os FBX:
#   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/bake_anims.gd

const OUT_PATH := "res://anims/ronaldo_anims.res"

# nome usado no jogo -> arquivo fonte
const CLIPS := {
	"Idle":        "res://anims/ronaldo_mixamo/Offensive Idle.fbx",
	"Running":     "res://anims/ronaldo_mixamo/Running.fbx",
	"Kick":        "res://anims/ronaldo_mixamo/Kick Soccerball.fbx",
	"Header":      "res://anims/ronaldo_mixamo/Soccer Header.fbx",
	"Pass":        "res://anims/ronaldo_mixamo/Soccer Pass.fbx",
	"PenaltyKick": "res://anims/ronaldo_mixamo/Soccer Penalty Kick.fbx",
	"ScissorKick": "res://anims/ronaldo_mixamo/Scissor Kick.fbx",
}

const LOOPING := ["Idle", "Running"]

# esqueleto no FBX: "Skeleton3D"; no ronaldo.glb: "RonaldoArmature/Skeleton3D"
const SRC_PREFIX := "Skeleton3D:"
const DST_PREFIX := "RonaldoArmature/Skeleton3D:"

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

		for i in range(anim.get_track_count() - 1, -1, -1):
			var p := String(anim.track_get_path(i))
			var is_hips_track := p.ends_with(":mixamorig_Hips")
			if (
				anim.track_get_type(i) == Animation.TYPE_POSITION_3D
				or (is_hips_track and anim.track_get_type(i) == Animation.TYPE_ROTATION_3D)
			):
				anim.remove_track(i)
				continue
			if p.begins_with(SRC_PREFIX):
				anim.track_set_path(i, NodePath(DST_PREFIX + p.substr(SRC_PREFIX.length())))

		anim.loop_mode = Animation.LOOP_LINEAR if clip_name in LOOPING else Animation.LOOP_NONE
		lib.add_animation(clip_name, anim)
		print("OK  %-12s tracks=%d len=%.2f loop=%s" % [clip_name, anim.get_track_count(), anim.length, clip_name in LOOPING])
		scene.free()

	var err := ResourceSaver.save(lib, OUT_PATH)
	print("save -> ", OUT_PATH, "  err=", err)
	quit()
