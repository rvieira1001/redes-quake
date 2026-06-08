# Importar módulo de socket

from socket import *
import sys  # Para encerrar o programa

import random
import json


# Importar threading para usar no TCP, a ideia é manter um servidor sempre aceitando novas conexões,
# e usar uma thread nova para cada conexão já formada, sem ficar com o código preso no loop do aaccept()
import threading

# Cria uma lista pra salvar as conexões TCP, e enviar para todas sempre que precisar
clientes = []

class Player:
    def __init__(self, addr: socket, name: str):
        self.addr = addr
        self.name = name

        self.ready = False
        self.loaded = False

        self.score = 0
    
    def load_info(self, idx_spawn: int):
        return {"name": self.name, "spawn": idx_spawn}


# ID para o próximo jogador, vai incrementando
global prox_id
prox_id = 0

# Dicionário que leva id -> Player
global jogadores
jogadores: dict[int, Player] = {}

# Dicionário que leva socket -> id
global conexoes
conexoes: dict[socket, int] = {}

# Informações do jogo
QTD_SPAWNPOINTS = 8

def remover_cliente(cli: socket):
    if cli in clientes:
        clientes.remove(cli)
        print(conexoes)
        id = conexoes.get(cli)
        if (id != None):
            del jogadores[id]
            del conexoes[cli]
        print(f"Cliente removido com ID: {id}")


def mensagem_tcp(msg: str):
    cli: socket
    for cli in list(clientes):
        try:
            cli.sendall(msg.encode("utf-8"))
        except Exception:
            # Um erro pra enviar msg significa que não está mais conectado
            remover_cliente(cli)

def thread_tcp(conn, addr):
    global prox_id
    global jogadores
    global conexoes

    p_id: int = -1

    print(f"[TCP] Novo cliente conectado: {addr}")
    clientes.append(conn)

    try:
        while True:
            data = conn.recv(1024)
            if not data:
                break
            msg: str = data.decode().strip()
            print(f"[TCP] Mensagem recebida de {addr}: {msg}")

            cmd = msg.split(maxsplit=1)

            # Adicionar novo jogador à lista do servidor
            # 'ADDPLAYER [player_name]'
            if cmd[0] == 'ADDPLAYER':
                p_id = prox_id

                conexoes[conn] = p_id
                jogadores[p_id] = Player(addr, cmd[1])
                conn.sendall(f'SET_ID {p_id}'.encode("utf-8"))

                prox_id += 1

            
            # Marcar jogador como preparado pro inicio do jogo, e verifica se todos estão prontos
            # 'READY'
            elif cmd[0] == 'READY':
                jogadores[p_id].ready = True

                qtd_ready = 0
                qtd_clientes = 0
                for cli in list(clientes):
                    id = conexoes[cli]
                    qtd_clientes += 1
                    if jogadores.get(id).ready == True: qtd_ready += 1
                
                # Todos prontos para começar o jogo
                if (qtd_clientes == qtd_ready):
                    print("[DEBUG] Pronto para começar!")

                    ordem_spawn = []
                    for i in range(0, QTD_SPAWNPOINTS):
                        ordem_spawn.append(i)
                    
                    random.shuffle(ordem_spawn)

                    idx_spawn = 0
                    info_jogadores = {}
                    for cli in clientes:
                        id = conexoes[cli]
                        info_jogadores[id] = jogadores[id].load_info(ordem_spawn[idx_spawn])
                        idx_spawn += 1
                    
                    info_jogadores = json.dumps(info_jogadores)

                    mensagem_tcp(f"LOAD_GAME {qtd_clientes} {info_jogadores}")

            # Marcar jogador como não-preparado pro início do jogo
            # 'UNREADY'
            elif cmd[0] == 'UNREADY':
                jogadores[p_id].ready = False
            
            # Marcar que um jogador carregou o jogo, pronto para começar
            # 'LOADED'
            elif cmd[0] == 'LOADED':
                jogadores[p_id].loaded = True

                qtd_loaded = 0
                qtd_clientes = 0
                for cli in list(clientes):
                    id = conexoes[cli]
                    qtd_clientes += 1
                    if jogadores.get(id).loaded == True: qtd_loaded += 1
                
                # Todos prontos para começar o jogo
                if (qtd_clientes == qtd_loaded):
                    print("[DEBUG] Todos carregados!")

                    mensagem_tcp(f"START_GAME")
            
            # Enviar texto para todos os clientes (chats)
            # 'TEXT [msg...]'
            elif cmd[0] == 'TEXT':
                name = jogadores.get(p_id).name
                mensagem_tcp(f"TEXT {name} {cmd[1]}")
            
            # Jogador morreu sozinho
            # 'DEATH'
            elif cmd[0] == 'DEATH':
                # Vai enviar um TCP pros clientes: 'DEATH [id] [idx_respawn]', que "desliga" o jogador morto
                # em todos os clietes, e o cliente do jogador que morreu respawna no spawn de índice enviado 

                # Morreu sozinho = perde 1 ponto
                jogadores.get(p_id).score -= 1

                idx_respawn = random.randint(0, QTD_SPAWNPOINTS-1)
                mensagem_tcp(f"DEATH {p_id} {idx_respawn}")
            
            # Jogador matou algum outro
            # 'KILL [id_alvo] [headshot? 0:1]'
            elif cmd[0] == 'KILL':
                # Vai enviar um TCP pros clientes: 'KILL [id_origem] [id_alvo] [idx_respawn] [headshot?]', que "desliga" o jogador morto
                # em todos os clietes, e o cliente do jogador que morreu respawna no spawn de índice enviado, além de mostrar na tela 

                conteudo = cmd[1].split()
                id_alvo = int(conteudo[0])
                headshot = int(conteudo[1])

                # Se for headshot, ganha 2 pontos
                if (headshot == 1):
                    jogadores.get(p_id).score += 2
                else:
                    jogadores.get(p_id).score += 1

                idx_respawn = random.randint(0, QTD_SPAWNPOINTS-1)
                mensagem_tcp(f"KILL {p_id} {id_alvo} {idx_respawn} {headshot}")
    finally:
        remover_cliente(conn)
        
        conn.close()
        print(f"[TCP] Cliente desconectou: {addr}")

def server_tcp(PORT):
    socket_tcp = socket(AF_INET, SOCK_STREAM)

    # Pra reutilizar o mesmo port logo depois de fechar o TCP, precisa
    # de setar o SO_REUSEADDR, senão dá erro de "port already in use"
    socket_tcp.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)

    socket_tcp.bind(('', PORT))
    socket_tcp.listen()
    print(f"Socket TCP de accept() ligado na porta {PORT}.")

    # Estabelecer a conexão
    print('Ready to serve...')
    try:
        while True:
            connectionSocket, addr = socket_tcp.accept()

            # Cria uma thread pra cada cliente que conectar pelo TCP
            thread_cli = threading.Thread(target=thread_tcp, args=(connectionSocket, addr))
            thread_cli.daemon = True
            thread_cli.start()
    finally:
        print("Desligando o TCP de accept()")
        socket_tcp.close()

def server_udp(PORT: int):
    # Criação de socket UDP (Flag SOCK_DGRAM)
    socket_udp = socket(AF_INET, SOCK_DGRAM)

    # Preparar um socket de servidor UDP
    socket_udp.bind(('', PORT))

    print(f"Socket UDP conectado na porta {PORT}.")

    while True:
        try:
            # Read incoming data (buffer size is 1024 bytes)
            # recvfrom() returns the payload data and the sender's (IP, port) tuple
            data, client_address = socket_udp.recvfrom(1024)
            
            # Decode bytes to a string
            message = data.decode('utf-8')

            cmd: list[str] = message.split(maxsplit=1)
            if cmd[0] == 'POS':
                conteudo: list[str] = cmd[1].split(maxsplit=1)
                recv_id: int = int(conteudo[0])
                recv_pos: str = conteudo[1]


                response = f"POS {recv_id} {recv_pos}".encode('utf-8')

                for jog_id in jogadores.keys():
                    if jog_id != recv_id:
                        jog = jogadores[jog_id]
                        addr = jog.addr
                        socket_udp.sendto(response, addr)
            
        except KeyboardInterrupt:
            print("Desligando o UDP")
            socket_udp.close()
            break
    

def main():
    # Input pra escolher a porta dos dois servidores
    PORT = int(input("Informe a porta desejada: "))

    # Cria uma thread pro server TCP ficar recebendo o accept
    thread_tcp = threading.Thread(target=server_tcp, args=[PORT])

    # A flag deamon faz desligar a thread quando a main desligar
    thread_tcp.daemon = True 
    thread_tcp.start()

    # Roda o UDP na thread principal (poderia ser em outra thread também)
    try:
        server_udp(PORT)
    except KeyboardInterrupt:
        print("Desligando o programa todo (main)")


    sys.exit()  # Termina o programa após enviar os dados correspondentes

main()