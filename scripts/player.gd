extends CharacterBody3D

const WALK_SPEED = 5.0
const RUN_SPEED = 8.0
const JUMP_VELOCITY = 5.5
const MOUSE_SENSITIVITY = 0.0025

var camera_pivot: Node3D
var sword: Node3D
var attacking = false

func _ready():
    add_to_group("player")
    create_inputs()
    create_warrior()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func create_inputs():
    add_key("move_forward", KEY_W)
    add_key("move_backward", KEY_S)
    add_key("move_left", KEY_A)
    add_key("move_right", KEY_D)
    add_key("jump", KEY_SPACE)
    add_key("run", KEY_SHIFT)

func add_key(action: String, key: Key):
    if not InputMap.has_action(action):
        InputMap.add_action(action)

    var event = InputEventKey.new()
    event.physical_keycode = key
    InputMap.action_add_event(action, event)

func create_warrior():
    var collision = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    capsule.radius = 0.4
    capsule.height = 1.8
    collision.shape = capsule
    collision.position.y = 0.9
    add_child(collision)

    var body = MeshInstance3D.new()
    var body_mesh = CapsuleMesh.new()
    body_mesh.radius = 0.4
    body_mesh.height = 1.8
    body.mesh = body_mesh
    body.position.y = 0.9

    var skin = StandardMaterial3D.new()
    skin.albedo_color = Color(0.28, 0.12, 0.065)
    body.material_override = skin
    add_child(body)

    camera_pivot = Node3D.new()
    camera_pivot.position.y = 1.5
    add_child(camera_pivot)

    var arm = SpringArm3D.new()
    arm.spring_length = 5.0
    camera_pivot.add_child(arm)

    var camera = Camera3D.new()
    camera.current = true
    camera.fov = 75
    arm.add_child(camera)

    create_sword()

func create_sword():
    sword = Node3D.new()
    sword.position = Vector3(0.55, 1.0, -0.35)
    add_child(sword)

    var blade = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = Vector3(0.12, 0.9, 0.08)
    blade.mesh = mesh
    blade.position.y = 0.5

    var material = StandardMaterial3D.new()
    material.albedo_color = Color(0.72, 0.76, 0.8)
    blade.material_override = material
    sword.add_child(blade)

    var handle = MeshInstance3D.new()
    var handle_mesh = BoxMesh.new()
    handle_mesh.size = Vector3(0.16, 0.25, 0.14)
    handle.mesh = handle_mesh
    handle.position.y = -0.08

    var handle_mat = StandardMaterial3D.new()
    handle_mat.albedo_color = Color(0.25, 0.12, 0.05)
    handle.material_override = handle_mat
    sword.add_child(handle)

func _physics_process(delta):
    if not is_on_floor():
        velocity.y -= 9.8 * delta

    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = JUMP_VELOCITY

    var input_dir = Input.get_vector(
        "move_left",
        "move_right",
        "move_forward",
        "move_backward"
    )

    var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

    if direction:
        var speed = RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
        velocity.x = direction.x * speed
        velocity.z = direction.z * speed
    else:
        velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
        velocity.z = move_toward(velocity.z, 0, WALK_SPEED)

    move_and_slide()

func _unhandled_input(event):
    if event is InputEventMouseMotion:
        if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
            camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
            camera_pivot.rotation.x = clamp(
                camera_pivot.rotation.x,
                deg_to_rad(-60),
                deg_to_rad(45)
            )

    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
            attack()

func attack():
    if attacking:
        return

    attacking = true

    var tween = create_tween()
    tween.tween_property(sword, "rotation_degrees:x", -100.0, 0.12)
    tween.tween_property(sword, "rotation_degrees:x", 0.0, 0.2)
    tween.finished.connect(func(): attacking = false)
