extends Node3D
class_name GenericPlayerScript

const RESPAWN_TIME = 3.0

@onready var p_body = get_parent()
@onready var head_info: Node3D = get_node("HeadInfo")

@onready var is_local_player = false

var playerhud_started = false

var alive = true

var speed = 0
@export var MAX_SPEED = 7.0
@export var ACCEL = 0.7
@export var DECEL = 0.7
@export var JUMP_VELOCITY = 4.5
var mid_air = false

var friction = 1
@export var AIR_FRICTION = 0.1
@export var FLOOR_FRICTION = 1

var move_velocity: Vector3 = Vector3.ZERO
var added_velocity: Vector3 = Vector3.ZERO

# Get the gravity from the project settings to be synced with RigidDynamicBody nodes.
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var neck := p_body.get_node("Neck")
@onready var camera := p_body.get_node("Neck/Camera3D")

func _ready() -> void:
	pass
	
	#if is_local_player:
	#	head_info.hide()
	#else:
	#	head_info.set_head_info.rpc(SERVER.PLAYER_NAME, team)

func _unhandled_input(event: InputEvent) -> void:
	if is_local_player and CLIENT.game_started:
		if event is InputEventMouseButton:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif event.is_action_pressed("ui_cancel"):
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			if event is InputEventMouseMotion:
				neck.rotate_y(-event.relative.x * 0.005)
				camera.rotate_x(-event.relative.y * 0.008)
				camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _process(delta: float) -> void:
	if is_local_player and CLIENT.game_started:
		if not playerhud_started:
			if p_body.has_method("hide_body"): p_body.hide_body()
			playerhud_started = true
		
		if alive:
			
			# Morreu caindo do mapa
			if global_position.y < -30:
				CLIENT.tcp_send_msg("DEATH " + str(CLIENT.my_id))

func _physics_process(delta: float) -> void:
	if is_local_player and CLIENT.game_started:
		if alive:
			# Add the gravity.
			if not p_body.is_on_floor():
				mid_air = true
				move_velocity.y -= gravity * delta
				friction = AIR_FRICTION
			else:
				move_velocity.y = 0
				if mid_air:
					added_velocity.y = 0
				mid_air = false
				friction = FLOOR_FRICTION
			
			# Handle Jump.
			if Input.is_action_just_pressed("jump") and p_body.is_on_floor():
				move_velocity.y = JUMP_VELOCITY

			# Get the input direction and handle the movement/deceleration.
			# As good practice, you should replace UI actions with custom gameplay actions.
			var input_dir := Input.get_vector("left", "right", "forward", "back")
			var direction = (neck.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			if direction:
				move_velocity.x = move_toward(move_velocity.x, direction.x * speed, friction)
				move_velocity.z = move_toward(move_velocity.z, direction.z * speed, friction)
				
				speed = move_toward(speed, MAX_SPEED, ACCEL * friction)
			elif speed > 0:
				speed = move_toward(speed, 0, DECEL * friction)
				move_velocity.x = move_toward(move_velocity.x, speed, 0)
				move_velocity.z = move_toward(move_velocity.z, speed, 0)
			else:
				speed = 0
				move_velocity.x = move_toward(move_velocity.x, 0, MAX_SPEED)
				move_velocity.z = move_toward(move_velocity.z, 0, MAX_SPEED)

			p_body.velocity = move_velocity + added_velocity
			added_velocity = added_velocity.move_toward(Vector3.ZERO, friction)
			
			p_body.move_and_slide()
			
			var my_pos = str(p_body.global_position) + "|" + str(p_body.global_rotation) + "|(" + str(camera.global_rotation.x) + "," + str(neck.global_rotation.y) + ", 0.0)"
			CLIENT.udp_send_msg("POS %d %s" % [CLIENT.my_id, my_pos])

func set_local_player(value:bool, playername: String):
	is_local_player = value
	camera.current = value
	
	head_info.visible = not value
	head_info.player_name_label.text = playername

func die(dying_player_id:int):
	alive = false
	p_body.hide()
	p_body.collision_layer = 0
	p_body.collision_mask = 0
	
	await get_tree().create_timer(RESPAWN_TIME).timeout
	
	if is_local_player:
		pass
		#SERVER.game_node.respawn_player(dying_player_id)
	
	alive = true
	p_body.hide()
	p_body.collision_layer = 1
	p_body.collision_mask = 1
	pass
