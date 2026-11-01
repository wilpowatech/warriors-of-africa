extends Node3D

const ROUND_LENGTH := 90.0
const WALK_SPEED := 4.2
const JUMP_SPEED := 6.0
const GRAVITY := 18.0

var remaining_time := ROUND_LENGTH
var player_health := 100.0
var enemy_health := 100.0
var round_over := false
var player_blocking := false

var player: CharacterBody3D
var enemy: CharacterBody3D
var player_animation: AnimationPlayer
var enemy_animation: AnimationPlayer
var player_action_locked := false

var timer_label: Label
var status_label: Label
var player_health_label: Label
var enemy_health_label: Label


func _ready() -> void:
	get_window().title = "Warriors of Africa - 3D"

	_create_environment()
	_create_arena()
	_create_fighters()
	_create_camera()
	_create_hud()

	print("Warriors of Africa 3D foundation loaded.")


func _process(delta: float) -> void:
	if round_over:
		return

	remaining_time = maxf(0.0, remaining_time - delta)
	timer_label.text = "%02d:%02d" % [
		int(remaining_time) / 60,
		int(remaining_time) % 60
	]

	if remaining_time <= 0.0:
		_finish_round("TIME UP")

	if player_health <= 0.0:
		_finish_round("DEFEAT")

	if enemy_health <= 0.0:
		_finish_round("VICTORY")

	_update_health_display()


func _physics_process(delta: float) -> void:
	if round_over:
		return

	_update_player(delta)
	_update_enemy(delta)
	_face_opponents()


func _create_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()

	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.39, 0.34)
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	world.environment = environment
	add_child(world)

	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sunlight.light_energy = 1.25
	sunlight.shadow_enabled = true
	add_child(sunlight)


func _create_arena() -> void:
	# Main raised stone fighting platform
	var floor_body := StaticBody3D.new()
	floor_body.name = "ArenaFloor"
	add_child(floor_body)

	var floor_mesh := MeshInstance3D.new()
	var floor_shape := BoxMesh.new()
	floor_shape.size = Vector3(16.0, 0.4, 8.0)
	floor_mesh.mesh = floor_shape
	floor_mesh.position.y = -0.2
	floor_mesh.material_override = _material(Color(0.36, 0.27, 0.19))
	floor_body.add_child(floor_mesh)

	var floor_collision := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(16.0, 0.4, 8.0)
	floor_collision.shape = floor_box
	floor_collision.position.y = -0.2
	floor_body.add_child(floor_collision)

	# Dark stone platform sides
	_add_box(self, "PlatformFront", Vector3(16.2, 0.45, 0.18),
		Vector3(0.0, -0.42, 4.0), Color(0.16, 0.11, 0.09))
	_add_box(self, "PlatformBack", Vector3(16.2, 0.45, 0.18),
		Vector3(0.0, -0.42, -4.0), Color(0.16, 0.11, 0.09))
	_add_box(self, "PlatformLeft", Vector3(0.18, 0.45, 8.0),
		Vector3(-8.0, -0.42, 0.0), Color(0.16, 0.11, 0.09))
	_add_box(self, "PlatformRight", Vector3(0.18, 0.45, 8.0),
		Vector3(8.0, -0.42, 0.0), Color(0.16, 0.11, 0.09))

	# Gold geometric floor borders
	var gold := Color(0.78, 0.54, 0.25)
	_add_box(self, "FrontGoldBorder", Vector3(15.4, 0.025, 0.07),
		Vector3(0.0, 0.015, 3.55), gold)
	_add_box(self, "BackGoldBorder", Vector3(15.4, 0.025, 0.07),
		Vector3(0.0, 0.015, -3.55), gold)
	_add_box(self, "LeftGoldBorder", Vector3(0.07, 0.025, 7.1),
		Vector3(-7.65, 0.015, 0.0), gold)
	_add_box(self, "RightGoldBorder", Vector3(0.07, 0.025, 7.1),
		Vector3(7.65, 0.015, 0.0), gold)

	# Central arena emblem
	_add_box(self, "EmblemHorizontal", Vector3(1.8, 0.025, 0.07),
		Vector3(0.0, 0.025, 0.0), gold)
	_add_box(self, "EmblemVertical", Vector3(0.07, 0.025, 1.8),
		Vector3(0.0, 0.025, 0.0), gold)
	var diagonal_a := _add_box(self, "EmblemDiagonalA",
		Vector3(1.25, 0.025, 0.07), Vector3(0.0, 0.03, 0.0), gold)
	diagonal_a.rotation_degrees.y = 45.0
	var diagonal_b := _add_box(self, "EmblemDiagonalB",
		Vector3(1.25, 0.025, 0.07), Vector3(0.0, 0.03, 0.0), gold)
	diagonal_b.rotation_degrees.y = -45.0

	# Rear architectural wall and framing
	_add_box(self, "RearFoundation", Vector3(16.0, 0.55, 0.7),
		Vector3(0.0, 0.25, -4.65), Color(0.22, 0.15, 0.11))
	_add_box(self, "RearWall", Vector3(16.0, 4.5, 0.35),
		Vector3(0.0, 2.5, -6.2), Color(0.25, 0.17, 0.12))
	_add_box(self, "RearTopBeam", Vector3(16.4, 0.35, 0.65),
		Vector3(0.0, 4.85, -6.0), Color(0.49, 0.34, 0.20))

	# Stone columns, bases, caps and decorative bands
	for x in [-7.0, -4.7, -2.35, 0.0, 2.35, 4.7, 7.0]:
		_add_box(self, "ArenaColumn", Vector3(0.48, 3.6, 0.55),
			Vector3(x, 2.0, -5.65), Color(0.47, 0.35, 0.24))
		_add_box(self, "ColumnBase", Vector3(0.72, 0.28, 0.78),
			Vector3(x, 0.32, -5.65), Color(0.63, 0.45, 0.27))
		_add_box(self, "ColumnCap", Vector3(0.78, 0.28, 0.82),
			Vector3(x, 3.85, -5.65), Color(0.68, 0.49, 0.29))
		_add_box(self, "ColumnBand", Vector3(0.53, 0.12, 0.61),
			Vector3(x, 2.7, -5.65), gold)

	# Tiered spectator stands behind the fighting platform
	for row in range(3):
		var row_z := -4.95 - float(row) * 0.78
		var row_y := 0.65 + float(row) * 0.42
		_add_box(self, "SpectatorTier", Vector3(12.8, 0.32, 0.68),
			Vector3(0.0, row_y, row_z), Color(0.31, 0.21, 0.15))
		_add_box(self, "TierFrontTrim", Vector3(12.9, 0.07, 0.08),
			Vector3(0.0, row_y - 0.12, row_z + 0.32), gold)

	# Decorative banners with geometric patterns
	for x in [-5.8, -3.8, 3.8, 5.8]:
		_add_box(self, "WarriorBanner", Vector3(0.9, 1.5, 0.08),
			Vector3(x, 2.65, -5.30), Color(0.43, 0.10, 0.065))
		_add_box(self, "BannerPattern", Vector3(0.12, 0.8, 0.10),
			Vector3(x, 2.65, -5.22), gold)
		_add_box(self, "BannerCrossPattern", Vector3(0.52, 0.10, 0.10),
			Vector3(x, 2.65, -5.21), gold)

	# Side architectural pillars
	for x in [-8.0, 8.0]:
		_add_box(self, "SidePillar", Vector3(0.5, 3.0, 0.5),
			Vector3(x, 1.5, -2.9), Color(0.43, 0.31, 0.21))
		_add_box(self, "SidePillarCap", Vector3(0.75, 0.22, 0.75),
			Vector3(x, 3.05, -2.9), gold)

func _create_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "FightingCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.0
	camera.position = Vector3(0.0, 4.0, 15.0)
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.5, 0.0), Vector3.UP)


func _create_fighters() -> void:
	player = _create_fighter(
		"Player",
		Vector3(-3.0, 0.0, 0.0),
		"res://assets/characters/exports/Y_Bot_Fighter.glb"
	)

	enemy = _create_fighter(
		"Opponent",
		Vector3(3.0, 0.0, 0.0),
		"res://assets/characters/exports/X_Bot_Fighter.glb"
	)

	player_animation = player.get_node("Visual/AnimationPlayer")
	enemy_animation = enemy.get_node("Visual/AnimationPlayer")

	player_animation.animation_finished.connect(_on_player_animation_finished)

	_play_fighter_animation(player_animation, "Warrior Idle", true)
	_play_fighter_animation(enemy_animation, "Boxing", true)


func _create_fighter(
	fighter_name: String,
	spawn: Vector3,
	model_path: String
) -> CharacterBody3D:

	var fighter := CharacterBody3D.new()
	fighter.name = fighter_name
	fighter.position = spawn
	add_child(fighter)

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	fighter.add_child(collision)

	var model_scene := load(model_path) as PackedScene
	if model_scene == null:
		push_error("Could not load fighter model: " + model_path)
		return fighter

	var visual := model_scene.instantiate()
	visual.name = "Visual"
	fighter.add_child(visual)

	return fighter


func _play_fighter_animation(
	animation_player: AnimationPlayer,
	animation_name: String,
	should_loop: bool
) -> bool:

	if animation_player == null or not animation_player.has_animation(animation_name):
		push_warning("Missing fighter animation: " + animation_name)
		return false

	var animation := animation_player.get_animation(animation_name)
	animation.loop_mode = Animation.LOOP_LINEAR if should_loop else Animation.LOOP_NONE

	if animation_player.current_animation == animation_name and animation_player.is_playing():
		return true

	animation_player.play(animation_name)
	return true


func _play_player_action(animation_name: String) -> void:
	if player_action_locked:
		return

	if _play_fighter_animation(player_animation, animation_name, false):
		player_action_locked = true


func _on_player_animation_finished(_animation_name: StringName) -> void:
	if player_action_locked:
		player_action_locked = false


func _create_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var panel := ColorRect.new()
	panel.color = Color(0.035, 0.025, 0.02, 0.88)
	panel.position = Vector2(0, 0)
	panel.size = Vector2(1100, 88)
	canvas.add_child(panel)

	player_health_label = _make_label(
		canvas, "PLAYER  100 / 100", Vector2(30, 18), 23
	)

	enemy_health_label = _make_label(
		canvas, "OPPONENT  100 / 100", Vector2(820, 18), 23
	)

	timer_label = _make_label(
		canvas, "01:30", Vector2(500, 12), 34
	)

	status_label = _make_label(
		canvas, "ROUND 1", Vector2(485, 105), 22
	)

	_make_label(
		canvas,
		"A / D  MOVE     W  JUMP     J  PUNCH     K  KICK     L  BLOCK",
		Vector2(210, 605),
		17
	)


func _make_label(
	parent: Node,
	content: String,
	position: Vector2,
	font_size: int
) -> Label:

	var label := Label.new()
	label.text = content
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.96, 0.83, 0.59))
	parent.add_child(label)
	return label


func _update_player(delta: float) -> void:
	player_blocking = Input.is_key_pressed(KEY_L)

	var direction := 0.0

	if Input.is_key_pressed(KEY_A):
		direction -= 1.0

	if Input.is_key_pressed(KEY_D):
		direction += 1.0

	player.velocity.x = direction * WALK_SPEED
	player.velocity.z = 0.0

	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	elif Input.is_key_pressed(KEY_W):
		player.velocity.y = JUMP_SPEED

	if player_blocking:
		player.velocity.x *= 0.35

	player.move_and_slide()
	player.position.x = clampf(player.position.x, -6.5, 6.5)


	if not player_action_locked:
		if player_blocking:
			_play_fighter_animation(player_animation, "Blocking", true)
		elif absf(direction) > 0.1:
			_play_fighter_animation(player_animation, "Walking", true)
		else:
			_play_fighter_animation(player_animation, "Warrior Idle", true)


func _update_enemy(delta: float) -> void:
	var distance := player.position.x - enemy.position.x

	if absf(distance) > 1.7:
		enemy.velocity.x = signf(distance) * 2.0
		_play_fighter_animation(enemy_animation, "Walking", true)
	else:
		enemy.velocity.x = 0.0
		_play_fighter_animation(enemy_animation, "Boxing", true)

	enemy.velocity.z = 0.0

	if not enemy.is_on_floor():
		enemy.velocity.y -= GRAVITY * delta

	enemy.move_and_slide()
	enemy.position.x = clampf(enemy.position.x, -6.5, 6.5)


func _face_opponents() -> void:
	if player.position.x < enemy.position.x:
		player.rotation.y = PI / 2.0
		enemy.rotation.y = -PI / 2.0
	else:
		player.rotation.y = -PI / 2.0
		enemy.rotation.y = PI / 2.0


func _update_health_display() -> void:
	player_health_label.text = "PLAYER  %d / 100" % int(player_health)
	enemy_health_label.text = "OPPONENT  %d / 100" % int(enemy_health)


func _finish_round(message: String) -> void:
	round_over = true
	status_label.text = message + "  -  PRESS R TO RESTART"


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if round_over and event.keycode == KEY_R:
			get_tree().reload_current_scene()
			return

		if not round_over:
			if event.keycode == KEY_J:
				_play_player_action("Punching")
			elif event.keycode == KEY_K:
				_play_player_action("Roundhouse Kick")


func _add_box(
	parent: Node,
	box_name: String,
	dimensions: Vector3,
	location: Vector3,
	colour: Color
) -> MeshInstance3D:

	var instance := MeshInstance3D.new()
	instance.name = box_name

	var mesh := BoxMesh.new()
	mesh.size = dimensions

	instance.mesh = mesh
	instance.position = location
	instance.material_override = _material(colour)

	parent.add_child(instance)
	return instance


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.82
	return material
