extends Node3D

@onready var preload_mapa = preload("res://Jogo/Maps/dom_test/map.tscn")
@onready var preload_player = preload("res://Jogo/Player/HitscanPlayer.tscn")

var mapa: Node3D = null

func _ready() -> void:
	CLIENT.main_node = self

func load_map(qtd_players: int, info_players: Dictionary) -> void:
	print(qtd_players)
	print(info_players)
	
	var inst_mapa = preload_mapa.instantiate()
	add_child(inst_mapa)
	
	mapa = inst_mapa
	
	load_players(qtd_players, info_players)

func load_players(qtd: int, info_players: Dictionary) -> void:
	var spawners = mapa.find_child("Spawners").get_children()
	var players_parent = mapa.find_child("Players")
	
	for s_id in info_players.keys():
		var id = int(s_id)
		var info: Dictionary = info_players[s_id]
		
		var inst_player = preload_player.instantiate()
		inst_player.name = s_id
		
		players_parent.add_child(inst_player)
		
		inst_player.global_position = spawners[info['spawn']].global_position
		
		inst_player.init_player(id, info['name'], id == CLIENT.my_id)
	
	CLIENT.tcp_send_msg("LOADED")
	CLIENT.menu_node.hide()
