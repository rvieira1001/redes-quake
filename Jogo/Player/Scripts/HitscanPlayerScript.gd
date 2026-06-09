extends CharacterBody3D

@onready var generic = $GenericPlayerScript
@onready var hud = $CanvasLayer/PlayerHUD

@onready var p_id: int = -1

@onready var hitscan_raycast_area = $Neck/Camera3D/HitscanRaycastArea
@onready var hitscan_raycast_body = $Neck/Camera3D/HitscanRaycastBody

@onready var hitscan_mesh = $RayParent/HitscanMesh
@onready var hitscan_position = $Neck/Camera3D/HitscanPosition

var hitscan_timer = 0
@export var HITSCAN_DELAY = 3.0

@onready var mesh_body = $MeshBody
@onready var mesh_head = $Neck/Camera3D/MeshHead
@onready var mesh_view = $Neck/Camera3D/MeshView
@onready var neck = $Neck

func hide_body():
	mesh_body.hide()
	neck.hide()

func set_mesh_color(color: Color):
	var new_mat = StandardMaterial3D.new()
	new_mat.albedo_color = color
	
	mesh_body.set_surface_override_material(0, new_mat)
	mesh_head.set_surface_override_material(0, new_mat)
	mesh_view.set_surface_override_material(0, new_mat)

func init_player(id: int, playername: String, playercolor: Color, is_local: bool) -> void:
	CLIENT.players[str(id)] = self
	
	p_id = id
	
	set_mesh_color(playercolor)
	
	generic.set_local_player(is_local, id, playername)
	hud.visible = is_local

func _process(delta: float) -> void:
	if generic.is_local_player:
		
		if hitscan_timer > 0:
			hitscan_timer = move_toward(hitscan_timer, 0, delta)

func _physics_process(delta: float) -> void:
	if generic.is_local_player:
		if generic.alive and CLIENT.game_started:
			if Input.is_action_just_pressed("mouse_1") and (hitscan_timer == 0):
				hitscan_timer = HITSCAN_DELAY
				hud.blink_crosshair()
				
				# Atira localmente, pra saber se acertou
				shoot_hitscan(hitscan_position.global_position.x, hitscan_position.global_position.y, hitscan_position.global_position.z, hitscan_position.global_rotation.x, hitscan_position.global_rotation.y, hitscan_position.global_rotation.y)
				# Avisa do tiro pro TCP, só vai rodar se não for do ID local
				CLIENT.tcp_send_msg("SHOOT %.2f,%.2f,%.2f,%.2f,%.2f,%.2f" % [hitscan_position.global_position.x, hitscan_position.global_position.y, hitscan_position.global_position.z, hitscan_position.global_rotation.x, hitscan_position.global_rotation.y, hitscan_position.global_rotation.y])

func update_pos(pos_x: float, pos_y: float, pos_z: float, rot_x: float, rot_y: float):
	global_position.x = pos_x
	global_position.y = pos_y
	global_position.z = pos_z
	
	generic.neck.global_rotation.x = rot_x
	generic.neck.global_rotation.y = rot_y

func shoot_hitscan(pos_x: float, pos_y: float, pos_z: float, rot_x: float, rot_y: float, rot_z: float):
	hitscan_mesh.global_position.x = pos_x
	hitscan_mesh.global_position.y = pos_y
	hitscan_mesh.global_position.z = pos_z
	
	hitscan_mesh.global_rotation.x = rot_x
	hitscan_mesh.global_rotation.y = rot_y
	hitscan_mesh.global_rotation.z = rot_z
	
	if not generic.is_local_player:
		hitscan_mesh.show()
		await get_tree().create_timer(0.3).timeout
		hitscan_mesh.hide()
	else:
		detect_shoot_target()

func detect_shoot_target() -> void:
	var targetA = hitscan_raycast_area.get_collider()
	var targetB = hitscan_raycast_body.get_collider()
	
	if (targetA != null):
		if (targetB != null):
			if targetB.is_in_group("Map"):
				return
		
		var target_generic = targetA.get("generic")
		var indicator_color = Color.WHITE
		var target_id: int = -1
		
		var is_headshot = 0
		if "Hitbox" in targetA.name:
			target_generic = targetA.owner.get("generic")
			target_id = target_generic.p_body.p_id
			if "Head" in targetA.name:
				is_headshot = 1
				indicator_color = Color.ORANGE_RED
			
		if target_generic != null: # Is collision_body
			if generic.is_local_player and (target_generic.get("alive") == true):
				hud.blink_indicator(indicator_color)
				CLIENT.tcp_send_msg("KILL %d %d" % [target_id, is_headshot])

func die(idx_respawn: int):
	generic.die(idx_respawn)
