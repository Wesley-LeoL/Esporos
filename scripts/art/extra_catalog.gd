# GERADO por tools/build_extra_catalog.py - não edite à mão.
class_name ExtraCatalog
extends RefCounted
## Pacotes extras: Town Sampler (prédios e postes noturnos) e Neon District (objetos).
## c = centro da base no chão (px do quadro), fp = pegada em células 80x40,
## r = área útil [x0,y0,x1,y1], a = âncora no chão, radius = colisão (0 = sem colisão).

const TOWN_DIR := "res://assets/art/tiles/town/sprites_192/"
const ANIM_FRAMES := 16
const FRAME_MS := 120

const BUILDINGS := {
	"soviet_khrushchyovka": {"w": 390, "h": 365, "c": [146, 263], "fp": [4, 2], "anim": true, "peso_vila": 22, "peso_ruina": 10},
	"neon_noodle_corner": {"w": 199, "h": 215, "c": [67, 158], "fp": [2, 1], "anim": true, "peso_vila": 16, "peso_ruina": 4},
	"neon_shop_row": {"w": 207, "h": 195, "c": [78, 139], "fp": [2, 1], "anim": true, "peso_vila": 16, "peso_ruina": 4},
	"soviet_bus_station": {"w": 501, "h": 321, "c": [229, 194], "fp": [6, 5], "anim": true, "peso_vila": 4, "peso_ruina": 0},
}

const TOWN_PROPS := {
	"neon_neon_lamp": {"w": 140, "h": 136, "r": [45, 59, 62, 101], "a": [50, 98], "radius": 6, "anim": false},
	"neon_vending_machine": {"w": 140, "h": 136, "r": [41, 71, 58, 103], "a": [50, 100], "radius": 6, "anim": true},
	"soviet_lamp_post": {"w": 227, "h": 210, "r": [81, 68, 104, 153], "a": [83, 150], "radius": 7, "anim": false},
}

const NEON_DIR := "res://assets/art/tiles/neon_district/64px/individual/"
const NEON := {
	"cyber_0048": {"grupo": "rua", "r": [21, 16, 42, 59], "a": [31, 56], "radius": 6},  # Short security bollard
	"cyber_0056": {"grupo": "rua", "r": [18, 16, 44, 59], "a": [24, 56], "radius": 8},  # Curved industrial lamp post
	"cyber_0041": {"grupo": "rua", "r": [19, 22, 43, 59], "a": [32, 56], "radius": 7},  # Angular street trash bin
	"cyber_0072": {"grupo": "rua", "r": [19, 16, 43, 59], "a": [31, 56], "radius": 7},  # Public address speaker column
	"cyber_0496": {"grupo": "rua", "r": [4, 28, 59, 59], "a": [20, 56], "radius": 16},  # Interlocking floor wedge vehicle barrier
	"cyber_0512": {"grupo": "rua", "r": [17, 4, 46, 59], "a": [30, 56], "radius": 9},  # Entrance occupancy status pillar
	"cyber_0080": {"grupo": "rua", "r": [15, 16, 48, 59], "a": [32, 56], "radius": 10},  # Sewer ventilation mushroom pipe
	"cyber_0064": {"grupo": "chao", "r": [4, 22, 59, 59], "a": [32, 40], "radius": 0},  # Round sewer cover
	"cyber_0001": {"grupo": "vila", "r": [17, 16, 46, 59], "a": [29, 56], "radius": 9},  # Noodle vending machine
	"cyber_0008": {"grupo": "vila", "r": [14, 16, 49, 59], "a": [27, 56], "radius": 10},  # Battery rental station
	"cyber_0016": {"grupo": "vila", "r": [11, 16, 52, 59], "a": [28, 56], "radius": 12},  # Skewer grill food trolley
	"cyber_0024": {"grupo": "vila", "r": [15, 16, 48, 59], "a": [26, 56], "radius": 10},  # Street pharmacy dispenser
	"cyber_0032": {"grupo": "vila", "r": [17, 12, 45, 59], "a": [28, 56], "radius": 8},  # Public payphone booth
	"cyber_0081": {"grupo": "vila", "r": [7, 16, 56, 59], "a": [14, 56], "radius": 15},  # Freestanding wide digital billboard frame
	"cyber_0096": {"grupo": "vila", "r": [13, 16, 49, 59], "a": [44, 56], "radius": 11},  # Public transit map case
	"cyber_0176": {"grupo": "vila", "r": [21, 16, 41, 59], "a": [32, 56], "radius": 6},  # Transit card reader pedestal
	"cyber_0304": {"grupo": "vila", "r": [20, 20, 43, 59], "a": [30, 56], "radius": 7},  # Food order touch-screen pedestal
	"cyber_0312": {"grupo": "vila", "r": [10, 12, 52, 59], "a": [23, 56], "radius": 12},  # Food delivery pickup locker
	"cyber_0272": {"grupo": "vila", "r": [12, 20, 51, 59], "a": [23, 56], "radius": 12},  # Lidded domestic recycling station
	"cyber_0040": {"grupo": "vila", "r": [11, 16, 52, 59], "a": [29, 56], "radius": 12},  # Fishcake soup service cart
	"cyber_0200": {"grupo": "vila", "r": [13, 16, 50, 59], "a": [24, 56], "radius": 11},  # Station luggage locker bank
	"cyber_0161": {"grupo": "vila", "r": [12, 16, 51, 59], "a": [29, 56], "radius": 12},  # Compact delivery cargo pod
	"cyber_0121": {"grupo": "industria", "r": [5, 16, 57, 59], "a": [21, 56], "radius": 15},  # Large rooftop air conditioning unit
	"cyber_0128": {"grupo": "industria", "r": [20, 12, 43, 59], "a": [32, 56], "radius": 7},  # Small antenna mast
	"cyber_0136": {"grupo": "industria", "r": [11, 16, 51, 59], "a": [25, 56], "radius": 12},  # Emergency backup generator
	"cyber_0168": {"grupo": "industria", "r": [15, 22, 47, 59], "a": [26, 56], "radius": 9},  # Manual pallet jack
	"cyber_0184": {"grupo": "industria", "r": [18, 22, 45, 59], "a": [29, 56], "radius": 8},  # Vehicle battery swap cabinet
	"cyber_0192": {"grupo": "industria", "r": [12, 16, 50, 59], "a": [23, 56], "radius": 11},  # Freight hook hoist frame
	"cyber_0401": {"grupo": "industria", "r": [9, 4, 54, 59], "a": [26, 56], "radius": 13},  # Shielded transformer cabinet
	"cyber_0408": {"grupo": "industria", "r": [6, 4, 56, 59], "a": [18, 56], "radius": 15},  # Three-fin thermal radiator
	"cyber_0424": {"grupo": "industria", "r": [6, 4, 57, 59], "a": [24, 56], "radius": 15},  # Intake filtration housing
	"cyber_0432": {"grupo": "industria", "r": [9, 4, 53, 59], "a": [25, 56], "radius": 13},  # Ash collection vacuum drum
	"cyber_0536": {"grupo": "industria", "r": [9, 4, 54, 59], "a": [26, 56], "radius": 13},  # Emergency radio base station
	"cyber_0160": {"grupo": "industria", "r": [11, 16, 51, 59], "a": [24, 56], "radius": 12},  # Emergency battery storage rack
	"cyber_0416": {"grupo": "abrigo", "r": [12, 4, 51, 59], "a": [24, 56], "radius": 12},  # UV drinking-water purification column
	"cyber_0561": {"grupo": "abrigo", "r": [13, 4, 49, 59], "a": [26, 56], "radius": 11},  # Vertical lettuce hydroponic rack
	"cyber_0568": {"grupo": "abrigo", "r": [12, 4, 51, 59], "a": [26, 56], "radius": 12},  # Modular climbing bean trellis
	"cyber_0576": {"grupo": "abrigo", "r": [10, 4, 52, 59], "a": [24, 56], "radius": 12},  # Seed-bank cold vault
	"cyber_0584": {"grupo": "abrigo", "r": [10, 4, 53, 59], "a": [29, 56], "radius": 13},  # Compact atmospheric moisture collector
	"cyber_0592": {"grupo": "abrigo", "r": [6, 4, 56, 59], "a": [24, 56], "radius": 15},  # Roof rain capture collector
}
