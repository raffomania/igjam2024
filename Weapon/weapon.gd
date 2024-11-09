extends Area2D

@export
var throw_distance := 0.0
@export
var dash_curve: Curve
@export
var time_factor := 1.0
@export
var throw_range_factor := 1.0
@export
var stab_cooldown_seconds: float
@export
var stab_duration_seconds: float
@export
var stab_button_press_threshold_seconds: float

var throwing_time := 0.0
var is_throwing := false
var is_stabbing := false
var stab_on_cooldown := false
var dir
var weapon_owner
var attack_button_pressed := false
var attack_button_pressed_since: float

signal on_throw

# Called when the node enters the scene tree for the first throwing_time.
func _ready() -> void:
    area_entered.connect(_on_area_entered)


# Called every frame. 'delta' is the elapsed throwing_time since the previous frame.
func _process(delta: float) -> void:
    if is_throwing:
        throwing_time += delta * time_factor
        var curve_value = dash_curve.sample(throwing_time)
        throw_distance = curve_value * throw_range_factor
        global_position += dir * delta * throw_distance

    if throwing_time > 1.0:
        is_throwing = false
        throwing_time = 0

    if attack_button_pressed:
        attack_button_pressed_since += delta


func set_attack_button_pressed(now_pressed: bool) -> void:
    var just_pressed = not attack_button_pressed and now_pressed
    var just_released = attack_button_pressed and not now_pressed
    if just_pressed:
        attack_button_pressed = true
    if just_released:
        if attack_button_pressed_since < stab_button_press_threshold_seconds:
            stab()
        else:
            throw()
        attack_button_pressed = false
        attack_button_pressed_since = 0.0

func throw() -> void:
    dir = Vector2(0, -1).rotated(global_rotation)
    var main_scene = get_tree().get_root().get_node("Main")
    reparent(main_scene)
    is_throwing = true
    on_throw.emit()

func _on_area_entered(area) -> void:
    if throwing_time <= 1 and throwing_time > 0 and area.has_method("kill") and not area == weapon_owner:
         area.kill()

    if throwing_time == 0 and area.has_method("kill") and not area.holding_weapon:
        weapon_owner = area
        area.pick_up_weapon(self)

    if is_stabbing and area.has_method("kill"):
        area.kill()

func stab() -> void:
    if is_stabbing or stab_on_cooldown:
        return

    is_stabbing = true

    var x_before = position.x
    position.x += 30

    await get_tree().create_timer(stab_duration_seconds).timeout

    position.x = x_before
    is_stabbing = false
    stab_on_cooldown = true

    await get_tree().create_timer(stab_cooldown_seconds).timeout

    stab_on_cooldown = false
