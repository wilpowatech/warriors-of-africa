extends SceneTree

func _initialize() -> void:
    call_deferred("_inspect")

func _inspect() -> void:
    var paths := [
        "res://assets/characters/exports/Y_Bot_Fighter.glb",
        "res://assets/characters/exports/X_Bot_Fighter.glb"
    ]

    for path in paths:
        print("\n========== ", path, " ==========")

        var packed := load(path) as PackedScene
        if packed == null:
            print("ERROR: Could not load PackedScene")
            continue

        var root := packed.instantiate()
        _walk(root, "")

        root.free()

    quit()

func _walk(node: Node, indent: String) -> void:
    print(indent, node.name, " [", node.get_class(), "]")

    if node is AnimationPlayer:
        var player := node as AnimationPlayer
        print(indent, "ANIMATIONS:")
        for animation_name in player.get_animation_list():
            var animation := player.get_animation(animation_name)
            print(indent, "  ", animation_name,
                " | length: ", animation.length)

    if node is Skeleton3D:
        var skeleton := node as Skeleton3D
        print(indent, "SKELETON BONES: ", skeleton.get_bone_count())

    for child in node.get_children():
        _walk(child, indent + "  ")
