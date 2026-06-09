# Importar módulo de socket

from socket import *
import sys  # Para encerrar o programa

# Biblioteca random para escolher onde respawnar um jogador
import random

# Biblioteca json para enviar dados do jogador ao começar a partida (atualmente, nome e cor)
import json

# Biblioteca struct pra decodificar o id (int) no UDP
# (a posição é atualizada enviando bytes "crus", sem formatação, que são decodificados usando esse struct)
import struct


# Importar threading para usar no TCP, a ideia é manter um servidor sempre aceitando novas conexões,
# e usar uma thread nova para cada conexão já formada, sem ficar com o código preso no loop do aaccept()
import threading

# Cria uma lista pra salvar as conexões TCP, e enviar para todas sempre que precisar
clientes = []

# Classe player que armazena dados do jogador, principalmente pra conseguir diferenciar um do
# outro na pontuação e saber se todos estão prontos e se carregaram a partida direitinho
class Player:
    def __init__(self, addr: socket, name: str, color: str):
        self.addr = addr
        self.name = name
        self.color = color

        self.ready = False
        self.loaded = False

        self.score = 0
    
    def load_info(self, idx_spawn: int):
        return {"name": self.name, "color": self.color, "spawn": idx_spawn}


# ID para o próximo jogador, vai incrementando pra cada jogador ter um ID único
global prox_id
prox_id = 0

# Dicionário que leva id -> Player
global jogadores
jogadores: dict[int, Player] = {}

# Dicionário que leva socket -> id
global conexoes
conexoes: dict[socket, int] = {}

# Informações do jogo
QTD_SPAWNPOINTS = 8 # Quantidade de spawnpoints que um índice será escolhido aleatoriamente, define a quantidade máxima de jogadores, já que o spawn é diferente inicialmente


# Imprime o placar no console, eventualmente a ideia é passar pra tela do cliente
def imprime_placar():
    str_placar = "PLACAR:\n"
    for jog in jogadores.values():
        str_placar += f"{jog.name}  =  {jog.score}\n"

    print(str_placar)


# Remove um jogador/cliente de todas as listas relacionadas a ele
def remover_cliente(cli: socket):
    if cli in clientes:
        clientes.remove(cli)
        id = conexoes.get(cli)
        if (id != None):
            del jogadores[id]
            del conexoes[cli]
        print(f"Cliente removido com ID: {id}")


# Envia uma mensagem TCP pra todos os clientes salvos na lista de clientes
def mensagem_tcp(msg: str):
    cli: socket
    for cli in list(clientes):
        try:
            cli.sendall(msg.encode("utf-8"))
        except Exception:
            # Um erro pra enviar msg significa que não está mais conectado
            remover_cliente(cli)


# Thread TCP que conecta a um único cliente (p_id é o ID individual desse jogador)
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

            # cmd[0] é o "opcode" da função, vai dizer o que faz
            # cmd[1] é o resto da função, que vai ser tratada conforme forem precisos os argumentos

            # Muitas funções são "repassadas" pro cliente de forma semelhante, pq o cliente aborda de maneira diferente do servidor
            # A maior diferença é que o servidor passa para todos os clientes, então precisa avisar qual o ID do cliente que enviou a mensagem

            # Adicionar novo jogador à lista do servidor
            # 'ADDPLAYER [player_name]'
            if cmd[0] == 'ADDPLAYER':
                p_id = prox_id

                info: list[str] = cmd[1].split()

                conexoes[conn] = p_id
                jogadores[p_id] = Player(addr, info[0], info[1])
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
            

            # Enviar texto para todos os clientes (chats) -- OBS: Função não tem origem no cliente, pretendo fazer um chat de texto
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

                imprime_placar()

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

                imprime_placar()

                idx_respawn = random.randint(0, QTD_SPAWNPOINTS-1)
                mensagem_tcp(f"KILL {p_id} {id_alvo} {idx_respawn} {headshot}")
            

            # Jogador anunciou um tiro (faz mostrar a trajetoria)
            # 'SHOOT [vetores de posicao/rotacao]
            elif cmd[0] == 'SHOOT':
                # Vai repassar o valor do argumento pros clientes, o cliente vai fazer a trajetoria do tiro aparecer na posição certa (chamando função relacionada)

                mensagem_tcp(f"SHOOT {p_id} {cmd[1]}")

    finally:
        # Quando um cliente for desconectar, envia um aviso pros outros clientes tirarem o player do mapa deles
        remover_cliente(conn)

        mensagem_tcp(f"REMOVE_PLAYER {p_id}")
        
        conn.close()
        print(f"[TCP] Cliente desconectou: {addr}")


# Servidor TCP que vai ficar ouvindo o accept() e criando threads pra cada cliente novo
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

            # OBS: Eventualmente, a ideia é "travar" novas conexões depois que o jogo iniciar
    finally:
        print("Desligando o TCP de accept()")
        socket_tcp.close()


# Servidor UDP, que recebe e transmite a posição de um jogador pros demais
def server_udp(PORT: int):
    # Criação de socket UDP (Flag SOCK_DGRAM)
    socket_udp = socket(AF_INET, SOCK_DGRAM)

    # Preparar um socket de servidor UDP
    socket_udp.bind(('', PORT))

    print(f"Socket UDP conectado na porta {PORT}.")

    while True:
        try:
            data, client_address = socket_udp.recvfrom(1024)
            
            # Primeiro byte = ID (int) de quem enviou
            recv_id = struct.unpack('<i', data[0:4])[0]
            
            # Envia pros demais jogadores
            for jog_id in jogadores.keys():
                if jog_id != recv_id:
                    jog = jogadores[jog_id]
                    addr = jog.addr
                    socket_udp.sendto(data, addr)
            
            # OBS: Uma forma de deixar "seguro" seria criar uma lista de endereços conhecidos antes do
            # início do jogo, e depois sempre verificar se o endereço que enviou está nessa "whitelist"
            
        except KeyboardInterrupt:
            print("Desligando o UDP")
            socket_udp.close()
            break
    
# Main, só pra ficar separada da raíz do código python
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