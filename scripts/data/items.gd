class_name Items
extends RefCounted
## Instâncias de itens e operações sobre listas de itens (inventário, caixas, cadáveres).
##
## Uma instância é um Dictionary:
##   {"id": "maca", "n": 3, "venc": 1830.0}      perecível (venc = relógio em que estraga)
##   {"id": "cano", "n": 1, "dur": 87.0}         durabilidade 0-100
##   {"id": "bateria", "n": 1, "carga": 64.0}    carga/usos 0-100
##   {"id": "mascara", "n": 1, "dur": 90.0, "filtro": 55.0}
## Itens sem estado empilham livremente; perecíveis empilham se vencem no mesmo instante;
## itens com durabilidade ou carga ficam sempre um por instância. No inventário do
## sobrevivente cada instância ganha também um "u" (id único, para referências como a arma
## na mão). Uma lista de itens é um Array dessas instâncias.

const STATE_KEYS := ["dur", "carga", "venc", "filtro", "mun"]
## Itens renomeados entre versões (id antigo -> novo).
const RENAMED := {"manual_logica": "manual_metalurgia"}


## Relógio do mundo (Game.play_time). Sem o autoload (testes), 0.
static func now() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	var g: Node = tree.root.get_node_or_null("Game") if tree != null else null
	return float(g.get("play_time")) if g != null else 0.0


static func def(id: String) -> Dictionary:
	return DB.ITEMS.get(id, {})


static func stackable(id: String) -> bool:
	var d := def(id)
	return not d.has("dur") and not d.has("carga")


## Cria 'n' unidades novas (estado cheio) ou com estado sorteado por 'r'. Devolve uma lista.
static func make(id: String, n: int = 1, clock: float = -1.0, r: RandomNumberGenerator = null) -> Array:
	var out: Array = []
	if not DB.ITEMS.has(id) or n <= 0:
		return out
	var d := def(id)
	if clock < 0.0:
		clock = now()
	if stackable(id):
		var inst := {"id": id, "n": n}
		if d.has("validade"):
			var k := r.randf_range(0.35, 1.0) if r != null else 1.0
			inst["venc"] = snappedf(clock + float(d["validade"]) * k, 1.0)
		out.append(inst)
		return out
	for i in n:
		var inst2 := {"id": id, "n": 1}
		if d.has("dur"):
			inst2["dur"] = snappedf(r.randf_range(35.0, 100.0), 1.0) if r != null else 100.0
		if d.has("carga"):
			inst2["carga"] = snappedf(r.randf_range(25.0, 100.0), 1.0) if r != null else 100.0
		if String(d["tipo"]) == "mascara":
			inst2["filtro"] = 0.0
		if d.has("pente"):
			inst2["mun"] = float(r.randi_range(0, int(d["pente"]))) if r != null else 0.0
		out.append(inst2)
	return out


## {id: quantidade} -> lista (usado pelo sorteio de loot e para converter saves antigos).
static func from_counts(counts: Dictionary, r: RandomNumberGenerator = null, clock: float = -1.0) -> Array:
	var out: Array = []
	var keys := counts.keys()
	keys.sort()
	for k in keys:
		var id := str(k)
		id = RENAMED.get(id, id)
		for inst in make(id, int(counts[k]), clock, r):
			add(out, inst)
	return out


## Aceita uma lista (formato atual) ou um Dictionary {id: n} (saves da versão 3) e devolve
## uma lista limpa (tipos certos, itens desconhecidos descartados).
static func sanitize(v: Variant) -> Array:
	if v is Dictionary:
		return from_counts(v, null, 0.0)
	var out: Array = []
	if not v is Array:
		return out
	for raw in v:
		if not raw is Dictionary:
			continue
		var rid := str(raw.get("id", ""))
		rid = RENAMED.get(rid, rid)
		if not DB.ITEMS.has(rid):
			continue
		var inst := {"id": rid, "n": maxi(1, int(raw.get("n", 1)))}
		for k in STATE_KEYS:
			if raw.has(k):
				inst[k] = float(raw[k])
		if raw.has("u"):
			inst["u"] = int(raw["u"])
		out.append(inst)
	return out


## Cópia sem os ids únicos (para itens que saem do inventário).
static func strip(inst: Dictionary) -> Dictionary:
	var c := inst.duplicate()
	c.erase("u")
	return c


static func strip_all(list: Array) -> Array:
	var out: Array = []
	for inst in list:
		out.append(strip(inst))
	return out


static func can_merge(a: Dictionary, b: Dictionary) -> bool:
	if a["id"] != b["id"] or not stackable(a["id"]):
		return false
	return is_equal_approx(float(a.get("venc", -1.0)), float(b.get("venc", -1.0)))


## Junta a instância na lista (empilha quando dá). Não copia: a instância passa a ser da lista.
static func add(list: Array, inst: Dictionary) -> Dictionary:
	for other in list:
		if can_merge(other, inst):
			other["n"] = int(other["n"]) + int(inst["n"])
			return other
	list.append(inst)
	return inst


static func add_all(list: Array, items: Array) -> void:
	for inst in items:
		add(list, inst)


static func count(list: Array, id: String) -> int:
	var n := 0
	for inst in list:
		if inst["id"] == id:
			n += int(inst["n"])
	return n


static func total_units(list: Array) -> int:
	var n := 0
	for inst in list:
		n += int(inst["n"])
	return n


## Separa 'n' unidades de uma instância da lista (a instância some se acabar). Devolve a parte.
static func split(list: Array, inst: Dictionary, n: int) -> Dictionary:
	n = mini(n, int(inst["n"]))
	var part := inst.duplicate()
	part["n"] = n
	inst["n"] = int(inst["n"]) - n
	if int(inst["n"]) <= 0:
		list.erase(inst)
	return part


## Retira 'n' unidades de um tipo (os que vencem primeiro saem antes). Devolve as partes.
static func take(list: Array, id: String, n: int) -> Array:
	var out: Array = []
	if count(list, id) < n:
		return out
	var pool: Array = []
	for inst in list:
		if inst["id"] == id:
			pool.append(inst)
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("venc", 1e12)) < float(b.get("venc", 1e12)))
	for inst in pool:
		if n <= 0:
			break
		var k := mini(n, int(inst["n"]))
		out.append(split(list, inst, k))
		n -= k
	return out


# ------------------------------------------------------------------ medidas
static func unit_weight(inst: Dictionary) -> float:
	var d := def(inst["id"])
	var w := float(d.get("peso", 0.5))
	# galões e frascos ficam mais leves conforme esvaziam
	if d.has("carga") and String(d["tipo"]) in ["combustivel", "med"]:
		w *= 0.15 + 0.85 * float(inst.get("carga", 100.0)) / 100.0
	return w


static func weight(inst: Dictionary) -> float:
	return unit_weight(inst) * int(inst["n"])


static func volume(inst: Dictionary) -> float:
	return float(def(inst["id"]).get("vol", 0.5)) * int(inst["n"])


static func list_weight(list: Array) -> float:
	var w := 0.0
	for inst in list:
		w += weight(inst)
	return w


static func list_volume(list: Array) -> float:
	var v := 0.0
	for inst in list:
		v += volume(inst)
	return v


# ------------------------------------------------------------------ frescor
## 1 = fresco, 0 = estragado. Itens que não estragam: sempre 1.
static func freshness(inst: Dictionary, clock: float = -1.0) -> float:
	if not inst.has("venc"):
		return 1.0
	if clock < 0.0:
		clock = now()
	var total := float(def(inst["id"]).get("validade", 1.0))
	return clampf((float(inst["venc"]) - clock) / total, 0.0, 1.0)


static func spoiled(inst: Dictionary, clock: float = -1.0) -> bool:
	return inst.has("venc") and freshness(inst, clock) <= 0.0


## "Fresco", "Passado" ou "Estragado" (vazio para itens que não estragam).
static func fresh_label(inst: Dictionary, clock: float = -1.0) -> String:
	if not inst.has("venc"):
		return ""
	var f := freshness(inst, clock)
	if f <= 0.0:
		return "Estragado"
	if f < 0.35:
		return "Passado"
	return "Fresco"


## Texto curto do estado: "87%", "carga 64%", "Fresco"...
static func state_text(inst: Dictionary) -> String:
	var parts: Array[String] = []
	if inst.has("dur"):
		parts.append(("vedação %d%%" if inst["id"] == "mascara" else "durab. %d%%") % int(float(inst["dur"])))
	if inst.has("filtro"):
		parts.append("filtro %d%%" % int(float(inst["filtro"])))
	if inst.has("mun"):
		parts.append("%d/%d balas" % [int(float(inst["mun"])), int(def(inst["id"]).get("pente", 0))])
	if inst.has("carga"):
		var d := def(inst["id"])
		if d.has("uso_carga"):
			parts.append("%d usos" % ceili(float(inst["carga"]) / float(d["uso_carga"]) - 0.001))
		else:
			parts.append("carga %d%%" % int(float(inst["carga"])))
	var fl := fresh_label(inst)
	if fl != "":
		parts.append(fl)
	return " · ".join(parts)


## Nome com quantidade: "Maçã x3".
static func label(inst: Dictionary) -> String:
	var n := int(inst["n"])
	return DB.item_name(inst["id"]) + ("" if n == 1 else " x%d" % n)


static func describe_list(list: Array) -> String:
	var parts: Array[String] = []
	for inst in list:
		parts.append(label(inst))
	return ", ".join(parts)


## Ordena uma lista de itens: por tipo, depois nome, depois estado.
const SORT_ORDER := ["arma_fogo", "arma", "municao", "comida", "bebida", "cantil", "med", "analgesico", "supressor",
	"filtro", "mascara", "mochila", "coldre", "ferramenta", "lanterna", "pilha", "regador", "semente", "reparo",
	"bateria", "combustivel", "material", "kit", "implante", "manual"]


static func sort_list(list: Array) -> void:
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta := SORT_ORDER.find(String(def(a["id"]).get("tipo", "")))
		var tb := SORT_ORDER.find(String(def(b["id"]).get("tipo", "")))
		if ta != tb:
			return ta < tb
		if a["id"] != b["id"]:
			return DB.item_name(a["id"]) < DB.item_name(b["id"])
		return float(a.get("venc", a.get("dur", a.get("carga", 0.0)))) < float(b.get("venc", b.get("dur", b.get("carga", 0.0)))))


## Junta pilhas que podem ser unidas (depois de reorganizar).
static func compact(list: Array) -> void:
	var out: Array = []
	for inst in list:
		add(out, inst)
	list.assign(out)
