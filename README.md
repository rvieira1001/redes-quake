# Trabalho de Redes - Quake simpificado

Um protótipo de jogo estilo Quake, feito na [Godot Engine](https://godotengine.org/pt-br/) e conectado usando um servidor TCP/UDP em Python.

O trabalho conta com a sincronização do movimento dos jogadores de forma rápida (UDP), além de exigir atenção para algumas ações importantes e pontuais do ambiente do jogo (TCP).

Um desafio do trabalho foi manter e administrar essa conexão e instruções entre os programas, uma vez que a comunicação entre clientes foi feita totalmente através do servidor Python, ou seja, não foi usada nenhuma função do Godot que era pré-feita para Multiplayer, somente a conexão via pacotes e sockets UDP e TCP. 

<img width="1824" height="953" alt="exemplo-redes-quake" src="https://github.com/user-attachments/assets/ea8b303d-c5c0-4dad-8604-7e1fc5b00f12" />

## Tecnologias utilizadas
- [Godot Engine](https://godotengine.org/pt-br/), que usa GDScript
- Biblioteca socket e threading de Python

## Como executar
Você pode obter o cliente e servidor de duas formas:
### A partir do código-fonte
- Clone o repositório com: `git clone https://github.com/rvieira1001/redes-quake`
- Baixe o [Godot Game Engine](https://godotengine.org/download/) (Versão padrão, não a .NET)
- Execute o Godot e clique em "Importar", no canto superior esquerdo
- Escolha o arquivo `project.godot` da pasta clonada do git
- Escolha "Editar" para ver o projeto, ou "Executar" para rodar diretamente
    - É possível rodar o Godot da linha de comando, que faz aparecer os prints de debug do jogo no terminal. Porém, executar mais de instância 1 do jogo a partir do mesmo aplicativo mistura os prints e os tornam ilegíveis. Por isso, recomendo abrir uma única instância pelo Godot aberto pela linha de comando, e outras instâncias de um Godot aberto normalmente.
- Execute o servidor com `python server.py`
### A partir do arquivo exportado
- Vá para a página de [Releases](https://github.com/rvieira1001/redes-quake/releases/) do repositório e baixe os arquivos anexados. (Sem necessidade do código-fonte)
- Execute o servidor com `python server.py`
- Extraia o zip, e abra o cliente pelo arquivo `.x86_64`, ou pelo `.sh` (que abre com um console de debug)

## Como testar
- Inicie o servidor com `python server.py` e escolha uma porta para abrir o TCP/UDP
- Inicie alguns clientes (Máx. 8) conforme as instruções acima
- Insira o nome do jogador, escolha uma cor e coloque a porta do cliente.
    - Se o servidor estiver rodando na mesma máquina, as portas não podem ser iguais.
- Insira o endereço e a porta do servidor (se deixar o endereço em branco, ele conecta no localhost)
- Clique para conectar e espere o texto mudar para "CONECTADO!"
    - Caso não mude depois de ~2-3 segundos, houve algum erro na conexão.
- Quando todos os clientes/jogadores estiverem conectados, clique no último botão até que todos estejam **READY**

**OBS:** O código no Godot que se comunica com o servidor está em `Globals/CLIENT.gd`, o restante é voltado ao funcionamento do jogo em si.

## Funcionalidades implementadas
- Movimento sincronizado entre clientes
- Tiros são sinalizados com um feixe vermelho
- Acertos são indicados na tela, em branco no corpo e em laranja na cabeça (valem 2 pontos!)
- Pontuação aumenta ao acertar inimigos, e diminui ao morrer caindo do mapa
- Servidor e clientes tratam corretamente um jogador saindo no meio da partida

## Possíveis melhorias futuras
- Codificar os códigos TCP em bytes "crus", ao invés de textos ascii para economizar bytes enviados
- Adicionar um chat de texto (já criei o protocolo TCP 'TEXT [msg]', mas não é usado)
- Colocar um "histórico de abates" na HUD, listando quem acertou quem
- Colocar o placar de pontuação na tela (atualmente apenas no console do servidor)
- Melhorar esteticamente o jogo (adicionando sons e trocando texturas de prototipagem)
- Modificar o mapa do jogo, ou adicionar mais mapas
- Corrigir eventuais bugs que forem descobertos

## Bugs conhecidos
- Se você olhar completamente pra baixo e atirar, você atira em si mesmo, ganhando um ponto por isso

## Referências
- Material do laboratório de Servidor Web, da disciplina de Redes
- Documentação das bibliotecas de Python [Threading](https://docs.python.org/3/library/threading.html), [Socket](https://docs.python.org/3/library/socket.html) e [Struct](https://docs.python.org/3/library/struct.html)
- Documentação das classes em GDScript [PacketPeerUDP](https://docs.godotengine.org/en/stable/classes/class_packetpeerudp.html) e [StreamPeerTCP](https://docs.godotengine.org/en/stable/classes/class_streampeertcp.html)
