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
var player_color: Color = Color.WHITE
var game_started: bool = false

var players: Dictionary[String, Variant] = {}


func create_connection(playername: String, playercolor: Color, localport: int, address: String, port: int):
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
	player_color = playercolor
	
	await get_tree().create_timer(1.0).timeout
	
	tcp_send_msg("ADDPLAYER %s %s" % [playername, playercolor.to_html(false)])

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
				
				
				elif cmd[0] == "LOAD_GAME":
					var conteudo: PackedStringArray = cmd[1].split(" ", true, 1)
					var qtd: int = int(conteudo[0])
					var info_players = JSON.parse_string(conteudo[1].strip_edges())
					
					main_node.load_map(qtd, info_players)
				
				
				elif cmd[0] == "START_GAME":
					CLIENT.game_started = true
				
				
				elif cmd[0] == "KILL":
					var conteudo: PackedStringArray = cmd[1].split(" ", true)
					var id_killer: int = int(conteudo[0])
					var id_alvo: String = conteudo[1]
					var idx_respawn: int = int(conteudo[2])
					var is_headshot: bool = bool(int(conteudo[3]))
					players[id_alvo].die(idx_respawn)
				
				
				elif cmd[0] == "DEATH":
					var conteudo: PackedStringArray = cmd[1].split(" ", true)
					var id: String = conteudo[0]
					var idx_respawn: int = int(conteudo[1])
					players[id].die(idx_respawn)
				
				
				elif cmd[0] == "SHOOT":
					var conteudo: PackedStringArray = cmd[1].split(" ", true, 1)
					var id: String = conteudo[0]
					if (int(id) != my_id):
						var transform_valores: PackedStringArray = conteudo[1].split(",", true)
						var pos_x: float = float(transform_valores[0])
						var pos_y: float = float(transform_valores[1])
						var pos_z: float = float(transform_valores[2])
						var rot_x: float = float(transform_valores[3])
						var rot_y: float = float(transform_valores[4])
						var rot_z: float = float(transform_valores[5])
						
						players[id].shoot_hitscan(pos_x, pos_y, pos_z, rot_x, rot_y, rot_z)
				
				
				elif cmd[0] == "REMOVE_PLAYER":
					var s_id = cmd[1]
					var player = players.get(s_id)
					
					if (player != null):
						player.queue_free()
						players.erase(s_id)

func udp_listen():
	if udp_peer.get_available_packet_count() > 0:
		while udp_peer.get_available_packet_count() > 10:
			udp_peer.get_packet()
		
		
		var data = udp_peer.get_packet()
		
		var id: int = data.decode_s32(0)
		var pos_x: float = data.decode_float(4)
		var pos_y: float = data.decode_float(8)
		var pos_z: float = data.decode_float(12)
		var rot_x: float = data.decode_float(16)
		var rot_y: float = data.decode_float(20)
		
		var player = players.get(str(id))
		if player != null: player.update_pos(pos_x, pos_y, pos_z, rot_x, rot_y)

func udp_send_pos(pos_x: float, pos_y: float, pos_z: float, rot_x: float, rot_y: float):
	var pos_packet: PackedByteArray = PackedByteArray()
	
	pos_packet.resize(24) # 1 id (4 bytes) + 5 posicoes (5*4 = 20 bytes)
	pos_packet.encode_s32(0, my_id)
	pos_packet.encode_float(4, pos_x)
	pos_packet.encode_float(8, pos_y)
	pos_packet.encode_float(12, pos_z)
	pos_packet.encode_float(16, rot_x)
	pos_packet.encode_float(20, rot_y)
	
	udp_peer.put_packet(pos_packet)

func udp_send_msg(msg: String):
	var buffer = msg.to_utf8_buffer()
	udp_peer.put_packet(buffer)

func tcp_send_msg(msg: String):
	print("[TCP] ENVIANDO: %s" % msg)
	var buffer = msg.to_utf8_buffer()
	tcp_peer.put_data(buffer)
