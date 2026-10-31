import bpy
import json
import struct
from pathlib import Path

PROJECT = Path.home() / "Documents/WarriorsOfAfrica"
BASE = PROJECT / "assets/characters"
OUTPUT = BASE / "exports"

CHARACTERS = {
    "Y Bot": {
        "model": BASE / "source/Y Bot.fbx",
        "animations": BASE / "animations/source/Y-Bot",
        "output": OUTPUT / "Y_Bot_Fighter.glb",
        "expected": 20,
    },
    "X Bot": {
        "model": BASE / "source/X Bot.fbx",
        "animations": BASE / "animations/source/X-Bot",
        "output": OUTPUT / "X_Bot_Fighter.glb",
        "expected": 25,
    },
}


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def import_fbx(path):
    before_objects = set(bpy.data.objects)
    before_actions = set(bpy.data.actions)

    bpy.ops.wm.fbx_import(filepath=str(path))

    objects = [o for o in bpy.data.objects if o not in before_objects]
    actions = [a for a in bpy.data.actions if a not in before_actions]

    return objects, actions


def verify_glb(path, expected_names):
    data = path.read_bytes()

    magic, version, total_length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise RuntimeError("Invalid GLB header: " + str(path))

    chunk_length, chunk_type = struct.unpack_from("<II", data, 12)
    if chunk_type != 0x4E4F534A:
        raise RuntimeError("Missing GLB JSON chunk: " + str(path))

    gltf = json.loads(data[20:20 + chunk_length].decode("utf-8"))
    actual_names = {
        animation.get("name")
        for animation in gltf.get("animations", [])
    }

    missing = set(expected_names) - actual_names
    extra = actual_names - set(expected_names)

    print("Verified animation count:", len(actual_names))

    if missing or extra:
        raise RuntimeError(
            f"Animation mismatch. Missing={sorted(missing)}, "
            f"extra={sorted(extra)}"
        )

    print("All animation names verified.")


def export_character(name, config):
    print("\n" + "=" * 60)
    print("BUILDING:", name)
    print("=" * 60)

    clear_scene()

    model_path = config["model"]
    animation_dir = config["animations"]
    output_path = config["output"]

    if not model_path.exists():
        raise FileNotFoundError(model_path)

    if not animation_dir.is_dir():
        raise FileNotFoundError(animation_dir)

    model_objects, _ = import_fbx(model_path)

    armatures = [o for o in model_objects if o.type == "ARMATURE"]
    if len(armatures) != 1:
        raise RuntimeError(
            f"Expected one model armature, found {len(armatures)}"
        )

    target = armatures[0]
    print("Model armature:", target.name)
    print("Bones:", len(target.data.bones))

    animation_files = sorted(
        path for path in animation_dir.glob("*.fbx")
        if path.name.lower() != model_path.name.lower()
    )

    if len(animation_files) != config["expected"]:
        raise RuntimeError(
            f"{name}: expected {config['expected']} animations, "
            f"found {len(animation_files)}"
        )

    animation_data = target.animation_data_create()
    expected_names = []

    for index, animation_file in enumerate(animation_files, 1):
        clip_name = animation_file.stem

        print(
            f"[{index}/{len(animation_files)}] "
            f"Importing: {animation_file.name}"
        )

        imported_objects, actions = import_fbx(animation_file)

        if len(actions) != 1:
            raise RuntimeError(
                f"{animation_file.name}: expected one action, "
                f"found {len(actions)}"
            )

        action = actions[0]

        if len(action.slots) != 1:
            raise RuntimeError(
                f"{animation_file.name}: expected one action slot"
            )

        slot = action.slots[0]

        animation_data.action = action
        animation_data.action_slot = slot

        track = animation_data.nla_tracks.new()
        track.name = clip_name

        strip = track.strips.new(clip_name, 1, action)
        strip.action_slot = slot

        expected_names.append(clip_name)

        for obj in imported_objects:
            bpy.data.objects.remove(obj, do_unlink=True)

    animation_data.action = None

    if len(animation_data.nla_tracks) != len(animation_files):
        raise RuntimeError("NLA track count does not match animation count")

    print("\nNLA tracks created:", len(animation_data.nla_tracks))

    bpy.ops.object.select_all(action="DESELECT")

    for obj in model_objects:
        obj.select_set(True)

    bpy.context.view_layer.objects.active = target

    print("\nExporting:", output_path)

    result = bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_nla_strips=True,
        export_force_sampling=True,
    )

    if "FINISHED" not in result or not output_path.exists():
        raise RuntimeError("GLB export failed for " + name)

    print("File size:", output_path.stat().st_size, "bytes")

    verify_glb(output_path, expected_names)

    print("\nSUCCESS:", name)


OUTPUT.mkdir(parents=True, exist_ok=True)

for character_name, configuration in CHARACTERS.items():
    export_character(character_name, configuration)

print("\n" + "=" * 60)
print("ALL CHARACTER EXPORTS COMPLETED")
print("=" * 60)
