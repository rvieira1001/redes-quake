extends CharacterBody3D

@onready var generic = $GenericPlayerScript
@onready var hud = $CanvasLayer/PlayerHUD

@onready var hitscan_raycast_area = $Neck/Camera3D/HitscanRaycastArea
@onready var hitscan_raycast_body = $Neck/Camera3D/HitscanRaycastBody

@onready var hitscan_mesh = $RayParent/HitscanMesh
@onready var hitscan_position = $Neck/Camera3D/HitscanPosition

var hitscan_timer = 0
@export var HITSCAN_DELAY = 3.0
@export var HITSCAN_DMG = 800
@export var HITSCAN_HS = 1.5

@onready var mesh_body = $MeshBody
@onready var mesh_head = $Neck

func hide_body():
	mesh_body.hide()
	mesh_head.hide()

func init_player(id: int, playername: String, is_local: bool) -> void:
	CLIENT.players[str(id)] = self
	
	generic.set_local_player(is_local, playername)
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
				#shoot_hitscan.rpc(hitscan_position.global_transform)

func update_pos(new_pos_str: String):
	var new_pos = new_pos_str.split("|")
	global_position = str_to_var("Vector3"+new_pos[0])
	global_rotation = str_to_var("Vector3"+new_pos[1])
	generic.neck.global_rotation = str_to_var("Vector3"+new_pos[2])

func shoot_hitscan(angle):
	hitscan_mesh.global_transform = angle
	
	if not generic.is_local_player:
		hitscan_mesh.show()
	detect_shoot_target()
	
	await get_tree().create_timer(0.3).timeout
	
	hitscan_mesh.hide()

func detect_shoot_target() -> void:
	var targetA = hitscan_raycast_area.get_collider()
	var targetB = hitscan_raycast_body.get_collider()
	
	if (targetA != null):
		if (targetB != null):
			if targetB.is_in_group("Map"):
				return
		
		var b_gen = targetA.get("generic")
		var final_damage = HITSCAN_DMG
		var crosshair_color = Color.WHITE
		
		if "Hitbox" in targetA.name:
			b_gen = targetA.owner.get("generic")
			if "Head" in targetA.name:
				final_damage *= HITSCAN_HS
				crosshair_color = Color.ORANGE_RED
			
		if b_gen != null: # Is collision_body
			if generic.is_local_player and b_gen.has_method("take_damage") and (b_gen.get("alive") == true):
				var target_team = b_gen.get("team")
				if (target_team == -1) or (target_team == null) or (target_team != generic.team):
					generic.hud.blink_indicator(crosshair_color)
					b_gen.take_damage.rpc(final_damage, multiplayer.get_unique_id())
