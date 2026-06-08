extends Node

# Peers para conexão
var udp_peer: PacketPeerUDP = PacketPeerUDP.new()
var tcp_peer: StreamPeerTCP = StreamPeerTCP.new()

# Informações da conexão
var local_port: int = -1
var server_ip: String = ''
var server_port: int = -1

# Informações do jogo
var player_name: String = ''


func create_connection(playername: String, localport: int, address: String, port: int):
	# Conexão UDP
	var err = udp_peer.bind(localport)
	if err == OK:
		print("Peer UDP iniciado na porta %s" % localport)
	else:
		print("Erro no bind UDP: %s" % err)
	
	udp_peer.set_dest_address(address, port)
	print("Conectado ao socket UDP %s:%s" % [address, port])
	
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
	
	# isso aq seria no TCP
	udp_send_msg("ADD %s" % playername)
	
	# Conexão TCP
	pass
	
	local_port = localport
	server_ip = address
	server_port = port
	player_name = playername

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
				var msg = bytes.get_string_from_utf8()
				print("[TCP] RECEBIDO: ", msg)

func udp_listen():
	if udp_peer.get_available_packet_count() > 0:
		var data = udp_peer.get_packet()
		var msg = data.get_string_from_utf8()
		print("[UDP] RECEBIDO: ", msg)

func udp_send_msg(msg: String):
	print("[UDP] ENVIANDO: %s" % msg)
	var buffer = msg.to_utf8_buffer()
	udp_peer.put_packet(buffer)

func tcp_send_msg(msg: String):
	print("[TCP] ENVIANDO: %s" % msg)
	var buffer = msg.to_utf8_buffer()
	tcp_peer.put_data(buffer)
