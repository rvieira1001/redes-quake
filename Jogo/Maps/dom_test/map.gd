extends Node3D

@onready var capture_point = $Structure/CapturePoint
@onready var players_inside_point = []

@onready var label_team1 = $MapHUD/Control/CaptureInfo/Team1
@onready var label_team2 = $MapHUD/Control/CaptureInfo/Team2
@onready var label_current = $MapHUD/Control/CaptureInfo/Current

# Major capture progress
@onready var progress_team1 = 0.0
@onready var progress_team2 = 0.0

# Point take progress
@onready var captured_team = 0 #0, 1, 2
@onready var take_progress = 0.0 # -100(1) to +100(2)

@onready var capture_amount_team1 = 0
@onready var capture_amount_team2 = 0

var capture_base_speed = 5   # Base speed (1 player)
var capture_extra_speed = 2.5  # Extra speed (per extra player)

var major_progress_speed = 1.5

@onready var capture_progress = 0.0

func _ready() -> void:
	label_team1.modulate = DEBUG.ALLY_COLOR
	label_team2.modulate = DEBUG.ENEMY_COLOR
	
	if multiplayer.is_server():
		capture_point.connect("body_entered", _on_capture_point_body_entered)
		capture_point.connect("body_exited", _on_capture_point_body_exited)
		SERVER.game_node.connect("event_player_death", verify_alive_players_capturing)

func _process(delta: float) -> void:
	if multiplayer.is_server():
		var label1 = get_label(progress_team1, -1, capture_amount_team1)
		var label2 = get_label(progress_team2, +1, capture_amount_team2)
		rpc("set_capture_labels", label1, label2)
		
		if captured_team == 0: # Not captured yet
			if capture_amount_team1 != capture_amount_team2:
				var diff = capture_amount_team2 - capture_amount_team1
				var side = diff/abs(diff) # -1 or 1
				var extra = abs(diff) - 1
				
				take_progress = move_toward(take_progress, 100*side, delta*(capture_base_speed + (extra * capture_extra_speed)))
				if take_progress == -100:
					captured_team = 1
					take_progress = 0
				elif take_progress == +100:
					captured_team = 2
					take_progress = 0
		elif captured_team == 1:
			progress_team1 = move_toward(progress_team1, 100, delta*(major_progress_speed))
			
			var diff = max(0, capture_amount_team2 - capture_amount_team1)
			if diff > 0: # More attackers than defenders
				var extra = diff - 1
				var side = +1 # Team 2 = +1
				take_progress = move_toward(take_progress, 100*side, delta*(capture_base_speed + (extra * capture_extra_speed)))
				if take_progress == +100:
					captured_team = 2
					take_progress = 0
		elif captured_team == 2:
			progress_team2 = move_toward(progress_team2, 100, delta*(major_progress_speed))
			
			var diff = max(0, capture_amount_team1 - capture_amount_team2)
			if diff > 0: # More attackers than defenders
				var extra = diff - 1
				var side = -1 # Team 1 = -1
				take_progress = move_toward(take_progress, 100*side, delta*(capture_base_speed + (extra * capture_extra_speed)))
				if take_progress == -100:
					captured_team = 1
					take_progress = 0

@rpc("any_peer", "call_local", "unreliable")
func set_capture_labels(label1, label2):
	if SERVER.get_local_team() == 1:
		label_team1.text = label1
		label_team2.text = label2
	else:
		label_team1.text = label2
		label_team2.text = label1

func get_label(major, take, amount) -> String:
	var take_value = max(0.0, (take_progress * take))
	var txt = "[font_size=40]%d%%\n[font_size=24]%d%%\n[font_size=16] %d " % [major, take_value, amount]
	return txt

func _on_capture_point_body_entered(body: Node3D) -> void:
	print("%s entered, list: %s" % [body.name, players_inside_point])
	if not body.name in players_inside_point:
		players_inside_point.append(body.name)
		
		if body.generic.team == 1:
			capture_amount_team1 += 1
		elif body.generic.team == 2:
			capture_amount_team2 += 1

func _on_capture_point_body_exited(body: Node3D) -> void:
	if body.name in players_inside_point:
		players_inside_point.erase(body.name)
		
		if body.generic.team == 1:
			capture_amount_team1 -= 1
		elif body.generic.team == 2:
			capture_amount_team2 -= 1

func verify_alive_players_capturing() -> void:
	print("Verifying players in point after death")
	for body in capture_point.get_overlapping_bodies():
		print("Viewing: %s, alive? %s" % [body.name, body.generic.alive])
		if not body.generic.alive:
			if body.name in players_inside_point:
				players_inside_point.erase(body.name)
				
				if body.generic.team == 1:
					capture_amount_team1 -= 1
				elif body.generic.team == 2:
					capture_amount_team2 -= 1
