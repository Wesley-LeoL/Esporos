extends Node
## Sessão de rede (co-op de 2 a 4 jogadores). Modelo: um jogador hospeda e é a autoridade
## (servidor ENet); os outros entram pelo IP. O jogo solo usa OfflineMultiplayerPeer e passa
## pelos mesmos caminhos de código (o jogador local é o "servidor").
##
## Fluxo de entrada: cliente conecta -> envia _hello(versão, nome) -> servidor responde
## _welcome(seed, alterações do mundo) -> cliente gera o mundo e envia _client_ready ->
## servidor marca o jogador como pronto, cria o personagem dele e libera a replicação.

signal welcome_received(seed_value: int, snapshot: Dictionary)
signal peer_ready(peer: int)
signal peer_left(peer: int, name: String)
signal session_failed(reason: String)
signal ready_list_changed

const PORT := 7777
const MAX_PLAYERS := 4
const PROTOCOL := "esporos-net-1"

var player_name := "Sobrevivente"
var mode := ""  # "solo", "host" ou "client"
## peer -> nome (mantido pelo servidor e repassado a todos)
var names := {}
## peers que já geraram o mundo e podem receber entidades replicadas (todos sabem)
var ready_peers := {}
## Função que o servidor chama para montar o pacote de boas-vindas (definida pelo Main).
var snapshot_provider: Callable


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void: _fail("Não foi possível conectar ao anfitrião."))
	multiplayer.server_disconnected.connect(func() -> void: _fail("O anfitrião encerrou a sessão."))


# ------------------------------------------------------------------ consultas
func is_server() -> bool:
	return multiplayer.is_server()


func is_solo() -> bool:
	return mode == "solo"


func my_id() -> int:
	return multiplayer.get_unique_id()


func is_ready(peer: int) -> bool:
	return ready_peers.has(peer)


func name_of(peer: int) -> String:
	return str(names.get(peer, "Jogador %d" % peer))


# ------------------------------------------------------------------ iniciar / sair
## Inicia como anfitrião. Com coop = false é uma sessão local (solo), sem rede.
func host(coop: bool) -> bool:
	leave()
	if coop:
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_server(PORT, MAX_PLAYERS - 1)
		if err != OK:
			_fail("Não foi possível abrir a porta %d (erro %d)." % [PORT, err])
			return false
		multiplayer.multiplayer_peer = peer
		mode = "host"
	else:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		mode = "solo"
	names = {1: player_name}
	ready_peers = {1: true}
	return true


func join(address: String) -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(), PORT)
	if err != OK:
		_fail("Endereço inválido: %s" % address)
		return false
	multiplayer.multiplayer_peer = peer
	mode = "client"
	return true


func leave() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = ""
	names = {}
	ready_peers = {}


func _fail(reason: String) -> void:
	if mode == "":
		return
	leave()
	session_failed.emit(reason)


# ------------------------------------------------------------------ aperto de mão
func _on_connected() -> void:
	_hello.rpc_id(1, PROTOCOL, player_name)


func _on_peer_connected(_peer: int) -> void:
	pass  # o cliente se apresenta com _hello


@rpc("any_peer", "reliable")
func _hello(protocol: String, wanted_name: String) -> void:
	if not is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL:
		_refuse.rpc_id(peer, "Versão diferente do anfitrião.")
		return
	if names.size() >= MAX_PLAYERS:
		_refuse.rpc_id(peer, "A sessão está cheia (%d jogadores)." % MAX_PLAYERS)
		return
	var n := wanted_name.strip_edges().substr(0, 18)
	if n == "":
		n = "Jogador"
	var base := n
	var k := 2
	while names.values().has(n):
		n = "%s %d" % [base, k]
		k += 1
	names[peer] = n
	_set_names.rpc(names)
	var snap: Dictionary = snapshot_provider.call() if snapshot_provider.is_valid() else {}
	_welcome.rpc_id(peer, int(snap.get("seed", 0)), snap)


@rpc("authority", "reliable")
func _refuse(reason: String) -> void:
	_fail(reason)


@rpc("authority", "reliable")
func _welcome(seed_value: int, snapshot: Dictionary) -> void:
	welcome_received.emit(seed_value, snapshot)


## O cliente chama depois de gerar o mundo e aplicar as alterações.
func send_ready() -> void:
	if is_server():
		return
	_client_ready.rpc_id(1)


@rpc("any_peer", "reliable")
func _client_ready() -> void:
	if not is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if not names.has(peer):
		return
	ready_peers[peer] = true
	_set_ready.rpc(ready_peers)
	_apply_ready_change()
	peer_ready.emit(peer)


@rpc("authority", "reliable")
func _set_names(list: Dictionary) -> void:
	names = list


@rpc("authority", "reliable")
func _set_ready(list: Dictionary) -> void:
	ready_peers = list
	_apply_ready_change()


func _apply_ready_change() -> void:
	# cada lado reavalia a visibilidade dos sincronizadores que ele controla
	for s in get_tree().get_nodes_in_group("net_sync"):
		var sync := s as MultiplayerSynchronizer
		if sync.is_multiplayer_authority():
			sync.update_visibility()
	ready_list_changed.emit()


func _on_peer_disconnected(peer: int) -> void:
	if not is_server():
		return
	var n := name_of(peer)
	names.erase(peer)
	ready_peers.erase(peer)
	_set_names.rpc(names)
	_set_ready.rpc(ready_peers)
	_apply_ready_change()
	peer_left.emit(peer, n)


# ------------------------------------------------------------------ replicação
## Cria um MultiplayerSynchronizer para 'props' do nó (caminhos como ".:position").
## Só replica para jogadores prontos (que já geraram o mundo).
func make_sync(node: Node, props: Array, interval := 0.05, spawn_props := true) -> MultiplayerSynchronizer:
	var cfg := SceneReplicationConfig.new()
	for p in props:
		var path := NodePath(p)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		cfg.property_set_spawn(path, spawn_props)
	var sync := MultiplayerSynchronizer.new()
	sync.replication_config = cfg
	sync.root_path = NodePath("..")
	sync.replication_interval = interval
	sync.delta_interval = interval
	sync.add_visibility_filter(is_ready)
	sync.add_to_group("net_sync")
	node.add_child(sync)
	return sync
