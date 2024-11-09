extends Node2D

class_name Bottle

# Describes whether the Bottle is popped.
var popped = false
# Seconds until bottle pops.
var pop_countdown = 0
# Min/Max Time until bottle pops.
var pop_countdown_min = 10
var pop_countdown_max = 20

# The current rotational speed of the bottle
var rotation_speed: float = 0.5
# The max speed with which the bottle can rotate.
# `1` equals rotation per second in radians.
var max_rotation_speed: float = 1

var bottleneck_particles: GPUParticles2D
var pop_particles: GPUParticles2D
var inside_particles: GPUParticles2D
var player_has_entered := false

@onready
var entrance_area: Area2D = $EntranceArea
@onready
var bottle_cap: Sprite2D = $BottleCap
@onready
var body_area: Area2D = $BodyArea
@onready
var top_left_area: Area2D = $BodyTopLeft
@onready
var top_right_area: Area2D = $BodyTopRight
@onready
var bottom_left_area: Area2D = $BodyBottomLeft
@onready
var bottom_right_area: Area2D = $BodyBottomRight

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    # center the bottle
    var viewport = get_viewport_rect()

    position.x = viewport.size.x / 2
    position.y = viewport.size.y / 2

    var rng = RandomNumberGenerator.new()
    rng.seed = Time.get_unix_time_from_system()
    pop_countdown = rng.randi_range(pop_countdown_min, pop_countdown_max)

    bottleneck_particles = $BottleneckParticles
    pop_particles = $PopParticles
    inside_particles = $Line2D/InsideParticles
    entrance_area.area_entered.connect(_on_area_entered_entrance)
    body_area.area_entered.connect(_on_area_entered_body)
    top_left_area.area_entered.connect(_on_top_left_entered_body)
    top_right_area.area_entered.connect(_on_top_right_entered_body)
    bottom_left_area.area_entered.connect(_on_bottom_left_entered_body)
    bottom_right_area.area_entered.connect(_on_bottom_right_entered_body)


func _process(delta: float) -> void:
    if not popped:
        rotation += rotation_speed * delta
        pop_countdown -= delta

        if rotation_speed > 0:
            rotation_speed -= delta * 0.05
        elif rotation_speed < 0:
            rotation_speed += delta * 0.05

    # Check if the bottle should pop.
    if pop_countdown <= 0 or Input.is_action_just_pressed("debug_pop_bottle"):
        popped = true
        pop_bottle()


# Emits the popping particles.
func pop_bottle() -> void:
    bottle_cap.visible = false
    inside_particles.lifetime = 1
    inside_particles.emitting = false

    bottleneck_particles.emitting = true
    await get_tree().create_timer(0.7).timeout
    pop_particles.emitting = true
    await get_tree().create_timer(0.3).timeout
    bottleneck_particles.emitting = false
    # without this it breaks. do not ask why.
    await get_tree().create_timer(0.6).timeout
    pop_particles.emitting = false

# Call this to hit the bottle.
# Reduces the countdown until pop and adds some impulse to the bottle.
#
# `impulse`: equals the added rotations per second in radian.
# `countdown_reduction` (Optional): Set an explicit value for the countdown reduction.
#                                   If not provided, the impulse will be used to calculate this value.
func hit(impulse: float, countdown_reduction = null) -> void:
    if countdown_reduction != null:
        pop_countdown -= countdown_reduction
    else:
        pop_countdown -= impulse
    add_impulse(impulse)

# Adds an impulse to the rotation of the bottle.
# The impulse cannot be faster than `max_rotation_speed`.
#
# `impulse`: equals the added rotations per second in radian.
func add_impulse(impulse: float) -> void:
    rotation_speed += impulse

    # Limit the bottle rotation to the max possible speed
    if rotation_speed > max_rotation_speed:
        rotation_speed = max_rotation_speed
    elif rotation_speed < -max_rotation_speed:
        rotation_speed = -max_rotation_speed

func _on_area_entered_entrance(area: Area2D) -> void:
    if not is_instance_of(area, Player) or not popped or player_has_entered:
        return

    var player = area as Player
    var minigame = player.start_minigame()
    if is_instance_valid(minigame):
        minigame.finished.connect(func(): self.minigame_finished(player))


func minigame_finished(player: Player):
    if player_has_entered:
        return

    player_has_entered = true

    get_tree().root.get_node('Main').get_node('ScoringSystem').increase_score(player)

    var camera = get_tree().root.get_camera_2d()
    var zoom_tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
    zoom_tween.tween_property(camera, "zoom", Vector2(10, 10), 3.0)

    create_tween().tween_property(player, "rotation", player.rotation + PI * 2, 2.0)

    var tween = create_tween()
    tween.tween_property(player, "global_position", entrance_area.global_position, 0.4)
    await tween.finished

    tween = create_tween().parallel()
    tween.tween_property(player, "scale", player.scale * 0.6, 1.0)
    tween.tween_property(player, "global_position", global_position, 2.0)

    await zoom_tween.finished
    get_tree().root.get_node("Main").next_stage()

func _on_area_entered_body(area: Area2D) -> void:
    if is_instance_of(area, Player) and not player_has_entered:
        var player = area
        var direction = (player.global_position - get_viewport_rect().size / 2).normalized()
        var strenght_factor = 100
        player.bounce_back(direction * strenght_factor)
       
func _on_top_left_entered_body(area: Area2D) -> void:
    hit_bottle(area, "topleft")

func _on_top_right_entered_body(area: Area2D) -> void:
    hit_bottle(area, "topright")

func _on_bottom_left_entered_body(area: Area2D) -> void:
    hit_bottle(area, "bottomleft")

func _on_bottom_right_entered_body(area: Area2D) -> void:
    hit_bottle(area, "bottomright")

func hit_bottle(area: Area2D, direction: String) -> void:
    var impulse_direction = 0
    if direction == "topleft":
        impulse_direction = 1
    elif direction == "topright":
        impulse_direction = -1
    elif direction == "bottomleft":
        impulse_direction = -1
    elif direction == "bottomright":
        impulse_direction = 1
    
    if is_instance_of(area, WeaponHitbox) and not player_has_entered:
        var weapon = area.get_parent() as Weapon
        if weapon.is_throwing or weapon.is_stabbing:
            print("Hit impulse %s from direction %s" % [impulse_direction, direction])
            weapon.hit_bottle = true
            hit(0.25 * impulse_direction)

func get_bottle_floor(offset: int) -> Vector2:
    var bottle_size = $Line2D.get_viewport_rect().size
    return to_global(Vector2(0, (bottle_size.y / 2) + offset))
