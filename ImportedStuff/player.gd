extends CharacterBody3D
class_name Player
@export var mouse_sensitivity := 0.005
@export var move_speed := 3.0
@export var jump_strength := 5.0
@onready var camera : Camera3D = $Head/Camera3D
var gravity : float = 0.0
func _ready() -> void:
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera.make_current()
	else:
		set_process_input(false)
	pass
	
func _physics_process(delta: float) -> void:
	handle_anims(delta)
	if is_multiplayer_authority():
		move(delta)
	move_and_slide()
func handle_anims(delta : float) -> void:
	if !is_on_floor():
		$character_template/AnimationPlayer.play("jump")
		return
		
	if velocity.length() > 3.0:
		$character_template/AnimationPlayer.play("sprint")
	elif velocity.length() > 0.1:
		$character_template/AnimationPlayer.play("run")
	else:
		$character_template/AnimationPlayer.play("idle")
		
func move(delta : float) -> void:
	
	if !is_on_floor():
		gravity -= 9.8 * delta
	elif gravity < 0.0:
		gravity = 0.0
	
	var input_axis : Vector2 = Input.get_vector("left", "right", "forward", "down")
	var direction = camera.global_transform.basis * Vector3(input_axis.x, 0.0, input_axis.y)
	direction = direction.normalized()
	if Input.is_action_pressed("sprint"):
		direction *= 1.3
	velocity = velocity.move_toward(direction * move_speed, delta * 30)
	velocity.y = gravity
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * mouse_sensitivity
	if event.is_action_pressed("jump") and is_on_floor():
		gravity = jump_strength
