extends Node2D

const FLOOR_Y := 535.0
const ROUND_LENGTH := 90.0
const GRAVITY := 1500.0

var player_x := 300.0
var enemy_x := 800.0

var player_y := FLOOR_Y
var enemy_y := FLOOR_Y
var player_velocity_y := 0.0
var enemy_velocity_y := 0.0

var player_health := 100.0
var enemy_health := 100.0

var player_facing := 1.0
var enemy_facing := -1.0

var player_attack := ""
var enemy_attack := ""
var player_attack_time := 0.0
var enemy_attack_time := 0.0
var player_hit_done := false
var enemy_hit_done := false

var player_blocking := false
var enemy_blocking := false

var player_cooldown := 0.0
var enemy_cooldown := 0.0

var remaining_time := ROUND_LENGTH
var game_over := false
var result_text := ""
var ai_decision_timer := 0.0
var background_time := 0.0


func _ready() -> void:
    get_window().title = "Warriors of Africa"
    queue_redraw()


func _process(delta: float) -> void:
    background_time += delta

    if game_over:
        if Input.is_key_pressed(KEY_R):
            _restart()
        queue_redraw()
        return

    remaining_time = maxf(0.0, remaining_time - delta)

    player_cooldown = maxf(0.0, player_cooldown - delta)
    enemy_cooldown = maxf(0.0, enemy_cooldown - delta)

    _update_player(delta)
    _update_enemy(delta)
    _update_physics(delta)
    _update_attacks(delta)

    if remaining_time <= 0.0:
        if player_health > enemy_health:
            _finish_round("VICTORY!")
        elif enemy_health > player_health:
            _finish_round("DEFEAT!")
        else:
            _finish_round("DRAW!")

    if player_health <= 0.0:
        _finish_round("DEFEAT!")

    if enemy_health <= 0.0:
        _finish_round("VICTORY!")

    queue_redraw()


func _input(event: InputEvent) -> void:
    if game_over:
        return

    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_W:
                if player_y >= FLOOR_Y - 1.0:
                    player_velocity_y = -620.0

            KEY_J:
                _player_attack("punch")

            KEY_K:
                _player_attack("kick")

            KEY_U:
                _player_attack("special")


func _player_attack(kind: String) -> void:
    if player_attack != "" or player_cooldown > 0.0 or player_blocking:
        return

    player_attack = kind
    player_attack_time = 0.0
    player_hit_done = false
    player_cooldown = 0.35 if kind == "punch" else 0.55


func _update_player(delta: float) -> void:
    player_blocking = Input.is_key_pressed(KEY_L) and player_attack == ""

    if player_blocking:
        return

    if player_attack != "":
        return

    var direction := 0.0

    if Input.is_key_pressed(KEY_A):
        direction -= 1.0

    if Input.is_key_pressed(KEY_D):
        direction += 1.0

    player_x += direction * 300.0 * delta
    player_x = clampf(player_x, 70.0, 1030.0)


func _update_enemy(delta: float) -> void:
    ai_decision_timer -= delta

    if enemy_attack != "":
        enemy_blocking = false
        return

    var distance := absf(player_x - enemy_x)

    enemy_facing = -1.0 if enemy_x > player_x else 1.0

    if distance > 115.0:
        enemy_x += enemy_facing * 170.0 * delta
        enemy_blocking = false
    else:
        enemy_blocking = false

        if ai_decision_timer <= 0.0 and enemy_cooldown <= 0.0:
            ai_decision_timer = randf_range(0.7, 1.5)

            if randf() < 0.18:
                enemy_blocking = true
            elif randf() < 0.75:
                _enemy_attack("punch" if randf() < 0.5 else "kick")
            else:
                _enemy_attack("special")

    enemy_x = clampf(enemy_x, 70.0, 1030.0)


func _enemy_attack(kind: String) -> void:
    if enemy_attack != "" or enemy_cooldown > 0.0:
        return

    enemy_attack = kind
    enemy_attack_time = 0.0
    enemy_hit_done = false
    enemy_cooldown = 0.6 if kind == "special" else 0.4


func _update_physics(delta: float) -> void:
    player_velocity_y += GRAVITY * delta
    enemy_velocity_y += GRAVITY * delta

    player_y += player_velocity_y * delta
    enemy_y += enemy_velocity_y * delta

    if player_y > FLOOR_Y:
        player_y = FLOOR_Y
        player_velocity_y = 0.0

    if enemy_y > FLOOR_Y:
        enemy_y = FLOOR_Y
        enemy_velocity_y = 0.0

    player_facing = 1.0 if enemy_x > player_x else -1.0
    enemy_facing = -player_facing


func _update_attacks(delta: float) -> void:
    if player_attack != "":
        player_attack_time += delta
        var hit_time := 0.22 if player_attack == "punch" else 0.32
        var duration := 0.48 if player_attack == "punch" else 0.75

        if player_attack_time >= hit_time and not player_hit_done:
            player_hit_done = true
            var distance := absf(player_x - enemy_x)

            if distance < (155.0 if player_attack == "special" else 125.0):
                if not enemy_blocking:
                    enemy_health = maxf(0.0, enemy_health - _damage(player_attack))
                else:
                    enemy_health = maxf(0.0, enemy_health - 3.0)

        if player_attack_time >= duration:
            player_attack = ""

    if enemy_attack != "":
        enemy_attack_time += delta
        var hit_time := 0.22 if enemy_attack == "punch" else 0.32
        var duration := 0.48 if enemy_attack == "punch" else 0.75

        if enemy_attack_time >= hit_time and not enemy_hit_done:
            enemy_hit_done = true
            var distance := absf(player_x - enemy_x)

            if distance < (155.0 if enemy_attack == "special" else 125.0):
                if not player_blocking:
                    player_health = maxf(0.0, player_health - _damage(enemy_attack))
                else:
                    player_health = maxf(0.0, player_health - 3.0)

        if enemy_attack_time >= duration:
            enemy_attack = ""


func _damage(kind: String) -> float:
    match kind:
        "punch":
            return 8.0
        "kick":
            return 12.0
        "special":
            return 20.0
    return 5.0


func _finish_round(message: String) -> void:
    game_over = true
    result_text = message


func _restart() -> void:
    player_x = 300.0
    enemy_x = 800.0
    player_y = FLOOR_Y
    enemy_y = FLOOR_Y
    player_velocity_y = 0.0
    enemy_velocity_y = 0.0
    player_health = 100.0
    enemy_health = 100.0
    player_attack = ""
    enemy_attack = ""
    player_attack_time = 0.0
    enemy_attack_time = 0.0
    player_hit_done = false
    enemy_hit_done = false
    player_blocking = false
    enemy_blocking = false
    player_cooldown = 0.0
    enemy_cooldown = 0.0
    remaining_time = ROUND_LENGTH
    ai_decision_timer = 0.0
    game_over = false
    result_text = ""


# --------------------------------------------------
# ARENA AND GRAPHICS
# --------------------------------------------------

func _draw() -> void:
    _draw_arena()

    _draw_fighter(
        player_x, player_y, player_facing,
        player_attack, player_attack_time,
        player_blocking, 0, true
    )

    _draw_fighter(
        enemy_x, enemy_y, enemy_facing,
        enemy_attack, enemy_attack_time,
        enemy_blocking, 1, false
    )

    _draw_hud()

    if game_over:
        _draw_result()


func _draw_arena() -> void:
    draw_rect(Rect2(0, 0, 1100, 650), Color("#21152b"))
    draw_rect(Rect2(0, 0, 1100, 365), Color("#38243a"))

    # Sunset
    draw_circle(Vector2(550, 205), 100, Color("#e78a42"))
    draw_circle(Vector2(550, 205), 85, Color("#f5b75c"))

    # Distant mountains
    draw_colored_polygon(PackedVector2Array([
        Vector2(0, 390), Vector2(160, 245),
        Vector2(315, 390), Vector2(470, 265),
        Vector2(640, 390), Vector2(810, 240),
        Vector2(1100, 390)
    ]), Color("#50334a"))

    # African-inspired arena structures
    draw_rect(Rect2(75, 285, 95, 250), Color("#70472e"))
    draw_rect(Rect2(55, 270, 135, 25), Color("#c28a43"))
    draw_rect(Rect2(900, 285, 95, 250), Color("#70472e"))
    draw_rect(Rect2(880, 270, 135, 25), Color("#c28a43"))

    # Decorative pillars
    for i in range(5):
        var px := 95.0 + i * 22.0
        _line(Vector2(px, 310), Vector2(px, 515), 4.0, Color("#d6a45e"))

    for i in range(5):
        var px := 920.0 + i * 17.0
        _line(Vector2(px, 310), Vector2(px, 515), 4.0, Color("#d6a45e"))

    # Ground
    draw_rect(Rect2(0, FLOOR_Y, 1100, 115), Color("#513322"))
    draw_rect(Rect2(0, FLOOR_Y, 1100, 8), Color("#d49a4f"))

    # Arena floor patterns
    for i in range(11):
        var x := i * 110.0
        _line(Vector2(x, 545), Vector2(x + 55, 650), 2.0, Color("#815331"))

    # Decorative symbols
    for x in [250.0, 850.0]:
        draw_circle(Vector2(x, 420), 23, Color("#b8753f"))
        draw_circle(Vector2(x, 420), 15, Color("#38243a"))
        _line(Vector2(x - 10, 420), Vector2(x + 10, 420), 3.0, Color("#f2c36c"))
        _line(Vector2(x, 410), Vector2(x, 430), 3.0, Color("#f2c36c"))


func _draw_fighter(
    x: float,
    foot: float,
    facing: float,
    attack: String,
    attack_time: float,
    blocking: bool,
    palette: int,
    is_player: bool
) -> void:
    var skin := Color("#8c4c2f") if palette == 0 else Color("#5d3428")
    var skin_light := Color("#bd7950") if palette == 0 else Color("#9a5b3d")
    var cloth := Color("#b92736") if palette == 0 else Color("#176c57")
    var cloth_light := Color("#f2bd43") if palette == 0 else Color("#e7a33e")
    var trim := Color("#f3d58a")
    var dark := Color("#211b22")

    var bob := sin(background_time * 5.0) * 2.0
    var body_y := foot - 115.0 + bob

    # Ground shadow
    draw_ellipse_placeholder(Vector2(x, foot + 4), Vector2(45, 9), Color(0, 0, 0, 0.3))

    # Legs
    var leg_offset := 0.0
    if attack == "kick" and attack_time > 0.12:
        leg_offset = 24.0 * facing

    _line(
        Vector2(x - 12, body_y + 55),
        Vector2(x - 22, foot - 5),
        17.0, skin
    )
    _line(
        Vector2(x + 12, body_y + 55),
        Vector2(x + 23 + leg_offset, foot - 5),
        17.0, skin
    )

    # Leg wraps and footwear
    draw_rect(Rect2(x - 30, foot - 38, 17, 12), cloth_light)
    draw_rect(Rect2(x + 13 + leg_offset, foot - 38, 17, 12), cloth_light)
    _line(Vector2(x - 22, foot - 5), Vector2(x - 37, foot - 3), 11.0, dark)
    _line(Vector2(x + 23 + leg_offset, foot - 5), Vector2(x + 38 + leg_offset, foot - 3), 11.0, dark)

    # Waist cloth
    draw_colored_polygon(PackedVector2Array([
        Vector2(x - 25, body_y + 38),
        Vector2(x + 25, body_y + 38),
        Vector2(x + 20, body_y + 76),
        Vector2(x - 18, body_y + 76)
    ]), cloth)

    # Patterned waist sash
    for i in range(4):
        _line(
            Vector2(x - 18 + i * 10, body_y + 45),
            Vector2(x - 23 + i * 10, body_y + 70),
            3.0, cloth_light
        )

    # Torso
    draw_colored_polygon(PackedVector2Array([
        Vector2(x - 23, body_y - 2),
        Vector2(x + 23, body_y - 2),
        Vector2(x + 29, body_y + 46),
        Vector2(x - 29, body_y + 46)
    ]), cloth)

    # Chest decoration
    _line(Vector2(x - 19, body_y + 5), Vector2(x + 19, body_y + 36), 4.0, trim)
    _line(Vector2(x + 19, body_y + 5), Vector2(x - 19, body_y + 36), 4.0, trim)
    _line(Vector2(x - 22, body_y + 22), Vector2(x + 22, body_y + 22), 3.0, cloth_light)

    # Neck
    draw_rect(Rect2(x - 8, body_y - 15, 16, 18), skin)

    # Arms
    var arm_end := Vector2(x + facing * 48, body_y + 25)

    if blocking:
        arm_end = Vector2(x + facing * 42, body_y - 3)
    elif attack == "punch" and attack_time > 0.08:
        arm_end = Vector2(x + facing * 88, body_y + 12)
    elif attack == "special" and attack_time > 0.1:
        arm_end = Vector2(x + facing * 100, body_y - 5)

    _line(Vector2(x - facing * 20, body_y + 7), Vector2(x - facing * 43, body_y + 42), 15.0, skin)
    draw_circle(Vector2(x - facing * 43, body_y + 42), 9, skin_light)

    _line(Vector2(x + facing * 20, body_y + 7), arm_end, 16.0, skin)
    draw_circle(arm_end, 10, skin_light)

    # Arm bands
    _line(Vector2(x - facing * 32, body_y + 24), Vector2(x - facing * 38, body_y + 32), 5.0, cloth_light)
    _line((Vector2(x + facing * 20, body_y + 7) + arm_end) / 2.0,
        (Vector2(x + facing * 20, body_y + 7) + arm_end) / 2.0 + Vector2(0, 7),
        5.0, trim)

    # Head
    draw_circle(Vector2(x, body_y - 32), 22, skin)
    draw_circle(Vector2(x + facing * 8, body_y - 35), 3, dark)
    _line(Vector2(x + facing * 4, body_y - 22),
        Vector2(x + facing * 13, body_y - 21), 2.0, dark)

    # Hair / headgear
    if palette == 0:
        draw_arc(Vector2(x, body_y - 35), 23, PI, TAU, 18, dark, 10.0)
        draw_colored_polygon(PackedVector2Array([
            Vector2(x - 24, body_y - 43),
            Vector2(x - 15, body_y - 64),
            Vector2(x + 13, body_y - 62),
            Vector2(x + 25, body_y - 42),
            Vector2(x + 13, body_y - 47),
            Vector2(x - 12, body_y - 46)
        ]), Color("#17151b"))
        draw_rect(Rect2(x - 23, body_y - 47, 46, 7), cloth_light)
    else:
        draw_arc(Vector2(x, body_y - 35), 22, PI, TAU, 18, dark, 12.0)
        draw_colored_polygon(PackedVector2Array([
            Vector2(x - 28, body_y - 48),
            Vector2(x - 17, body_y - 70),
            Vector2(x + 17, body_y - 70),
            Vector2(x + 28, body_y - 48)
        ]), Color("#d6a43d"))
        _line(Vector2(x - 23, body_y - 49), Vector2(x + 23, body_y - 49), 6.0, cloth)

    # Jewellery and face markings
    draw_circle(Vector2(x - 20, body_y - 23), 4, cloth_light)
    _line(Vector2(x - 5, body_y - 12), Vector2(x + 5, body_y - 12), 2.0, Color("#e9b98d"))
    _line(Vector2(x + facing * 15, body_y - 37),
        Vector2(x + facing * 19, body_y - 31), 2.0, Color("#302027"))

    # Shield on the player's back / opponent's arm decoration
    if blocking:
        draw_circle(Vector2(x + facing * 48, body_y - 5), 22, cloth_light)
        draw_circle(Vector2(x + facing * 48, body_y - 5), 15, Color("#80502f"))
        _line(Vector2(x + facing * 48, body_y - 18),
            Vector2(x + facing * 48, body_y + 8), 3.0, trim)


func draw_ellipse_placeholder(pos: Vector2, size: Vector2, color: Color) -> void:
    draw_set_transform(pos, 0.0, size / Vector2(20, 20))
    draw_circle(Vector2.ZERO, 20.0, color)
    draw_set_transform(Vector2.ZERO)


func _draw_hud() -> void:
    # Top banner
    draw_rect(Rect2(0, 0, 1100, 92), Color("#17121d"))
    _line(Vector2(0, 92), Vector2(1100, 92), 4.0, Color("#d59b45"))

    draw_string(ThemeDB.fallback_font, Vector2(420, 29),
        "WARRIORS OF AFRICA", HORIZONTAL_ALIGNMENT_CENTER, -1, 23, Color("#f6d38a"))

    draw_string(ThemeDB.fallback_font, Vector2(30, 30),
        "ROYAL GUARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

    draw_string(ThemeDB.fallback_font, Vector2(1070, 30),
        "SPEAR MASTER", HORIZONTAL_ALIGNMENT_RIGHT, -1, 15, Color.WHITE)

    # Health backgrounds
    draw_rect(Rect2(30, 43, 420, 24), Color("#4b252d"))
    draw_rect(Rect2(650, 43, 420, 24), Color("#4b252d"))

    # Health bars
    draw_rect(Rect2(30, 43, 420.0 * player_health / 100.0, 24), Color("#dc3545"))
    draw_rect(Rect2(650 + 420.0 * (1.0 - enemy_health / 100.0), 43,
        420.0 * enemy_health / 100.0, 24), Color("#dc3545"))

    draw_rect(Rect2(30, 43, 420, 24), Color(1, 1, 1, 0), false, 2)
    draw_rect(Rect2(650, 43, 420, 24), Color(1, 1, 1, 0), false, 2)

    # Timer
    var seconds := int(ceil(remaining_time))
    var timer_text := "%02d:%02d" % [seconds / 60, seconds % 60]
    draw_string(ThemeDB.fallback_font, Vector2(550, 72),
        timer_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 27, Color("#ffffff"))

    # Control hints
    draw_string(ThemeDB.fallback_font, Vector2(550, 625),
        "A / D MOVE     W JUMP     J PUNCH     K KICK     L BLOCK     U SPECIAL",
        HORIZONTAL_ALIGNMENT_CENTER, -1, 15, Color("#f5d7a1"))


func _draw_result() -> void:
    draw_rect(Rect2(0, 0, 1100, 650), Color(0, 0, 0, 0.72))
    draw_string(ThemeDB.fallback_font, Vector2(550, 285),
        result_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 64,
        Color("#f4c76c"))
    draw_string(ThemeDB.fallback_font, Vector2(550, 350),
        "PRESS R TO FIGHT AGAIN", HORIZONTAL_ALIGNMENT_CENTER, -1, 24,
        Color.WHITE)


# Compatibility helper: existing game code supplies thickness before colour.
# Godot 4 expects colour before thickness.
func _line(start_point: Vector2, end_point: Vector2, thickness: float, tint: Color) -> void:
    draw_line(start_point, end_point, tint, thickness)
