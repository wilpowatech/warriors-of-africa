extends SceneTree

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    for path in [
        "res://assets/characters/exports/Y_Bot_Fighter.glb",
        "res://assets/characters/exports/X_Bot_Fighter.glb"
    ]:
        print("\n========== ", path, " ==========")
        var packed := load(path) as PackedScene
        if packed == null:
            print("Could not load model")
            continue

        var root := packed.instantiate()
        _print_meshes(root, "")
        root.free()

    quit()

func _print_meshes(node: Node, indent: String) -> void:
    if node is MeshInstance3D:
        var mesh_node := node as MeshInstance3D
        print(indent, node.name, " bounds: ", mesh_node.get_aabb())

    for child in node.get_children():
        _print_meshes(child, indent + "  ")
