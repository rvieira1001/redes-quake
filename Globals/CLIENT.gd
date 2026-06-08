extends Node

@onready var main_node: Node3D
@onready var menu_node: Control

# Peers para conexão
var udp_peer: PacketPeerUDP = PacketPeerUDP.new()
var tcp_peer: StreamPeerTCP = StreamPeerTCP.new()

# Informações da conexão
var local_port: int = -1
var server_ip: String = ''
var server_port: int = -1

var my_id: int = -1

# Informações do jogo
var player_name: String = ''
var game_started: bool = false

var players: Dictionary[String, Variant] = {}


func create_connection(playername: String, localport: int, address: String, port: int):
	# Conexão UDP
	var err = udp_peer.bind(localport)
	if err == OK:
		print("Peer UDP iniciado na porta %s" % localport)
	else:
		print("Erro no bind UDP: %s" % err)
	
	udp_peer.set_dest_address(address, port)
	print("Conectado ao socket UDP %s:%s" % [address, port])
	
	
	# Conexão TCP
	err = tcp_peer.bind(localport)
	if err == OK:
		print("Peer TCP iniciado na porta %s" % localport)
	else:
		print("Erro no bind TCP: %s" % err)
	
	err = tcp_peer.connect_to_host(address, port)
	if err == OK:
		print("Conectado ao socket TCP %s:%s" % [address, port])
	else:
		print("Erro ao conectar no TCP: %s" % err)
	
	
	local_port = localport
	server_ip = address
	server_port = port
	player_name = playername
	
	await get_tree().create_timer(1.0).timeout
	
	tcp_send_msg("ADDPLAYER %s" % playername)

func _process(_delta):
	tcp_peer.poll()
	
	tcp_listen()
	udp_listen()

func tcp_listen():
	if tcp_peer.get_status() == tcp_peer.STATUS_CONNECTED:
		var qtd_bytes = tcp_peer.get_available_bytes()
		if qtd_bytes > 0:
			var data = tcp_peer.get_data(qtd_bytes)
			var err = data[0]
			var bytes = data[1]
			
			if err == OK:
				var msg: String = bytes.get_string_from_utf8()
				print("[TCP] RECEBIDO: ", msg)
				
				
				var cmd: PackedStringArray = msg.split(" ", true, 1)
				
				if cmd[0] == "SET_ID":
					my_id = int(cmd[1])
				elif cmd[0] == "TEXT":
					# Connect num chat da HUD
					var text_msg = cmd[1].split(" ", true, 1)
					print("%s: %s" % [text_msg[0], text_msg[1]])
				if cmd[0] == "LOAD_GAME":
					var conteudo: PackedStringArray = cmd[1].split(" ", true, 1)
					var qtd: int = int(conteudo[0])
					var info_players = JSON.parse_string(conteudo[1].strip_edges())
					
					main_node.load_map(qtd, info_players)
				if cmd[0] == "START_GAME":
					CLIENT.game_started = true

func udp_listen():
	if udp_peer.get_available_packet_count() > 0:
		var data = udp_peer.get_packet()
		var msg = data.get_string_from_utf8()
		
		var cmd: PackedStringArray = msg.split(" ", true, 1)
		if cmd[0] == "POS":
			var conteudo: PackedStringArray = cmd[1].split(" ", true, 1)
			var id = conteudo[0]
			var pos = conteudo[1]
			players[id].update_pos(pos)

func udp_send_msg(msg: String):
	var buffer = msg.to_utf8_buffer()
	udp_peer.put_packet(buffer)

func tcp_send_msg(msg: String):
	print("[TCP] ENVIANDO: %s" % msg)
	var buffer = msg.to_utf8_buffer()
	tcp_peer.put_data(buffer)
