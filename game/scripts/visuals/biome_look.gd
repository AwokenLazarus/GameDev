class_name BiomeLook
extends Resource
## Art direction for one sector's stage: floor, masonry, light and grade. Painterly dust,
## crimson, bone, iron and moonlight (bible §11); every sector keeps its own key colour.

@export var paving := 0.7
@export var tile := 72.0
@export var stone_a := Color(0.36, 0.31, 0.28)
@export var stone_b := Color(0.25, 0.22, 0.22)
@export var earth_a := Color(0.34, 0.26, 0.18)
@export var earth_b := Color(0.2, 0.15, 0.12)
@export var stain := 0.25
@export var wall_stone := Color(0.3, 0.27, 0.27)
@export var wall_height := 124.0
## Votive light in the wall niches and on landmarks.
@export var flame := Color(1.0, 0.58, 0.24)
@export var ambient := Color(0.62, 0.62, 0.74)
@export var moon := Color(0.62, 0.7, 0.95)
@export var haze := Color(0.09, 0.07, 0.1)
@export var mote := Color(0.85, 0.75, 0.55, 0.5)
@export var shadow_tint := Color(0.07, 0.05, 0.12)
@export var light_tint := Color(1.0, 0.92, 0.82)
@export var vista_dim := 0.62
## Large pieces that stand outside the back walls; small ones that sit on the floor.
@export var skyline: PackedStringArray = ["ruin"]
@export var clutter: PackedStringArray = ["crate"]


static func for_sector(id: String) -> BiomeLook:
	var k := BiomeLook.new()
	match id:
		"dust_meridian":
			k.paving = 0.42
			k.stone_a = Color(0.42, 0.34, 0.26)
			k.stone_b = Color(0.27, 0.22, 0.19)
			k.earth_a = Color(0.44, 0.32, 0.19)
			k.earth_b = Color(0.24, 0.17, 0.11)
			k.wall_stone = Color(0.36, 0.29, 0.24)
			k.flame = Color(1.0, 0.6, 0.22)
			k.ambient = Color(0.7, 0.64, 0.66)
			k.haze = Color(0.13, 0.085, 0.06)
			k.mote = Color(0.95, 0.78, 0.5, 0.5)
			k.shadow_tint = Color(0.09, 0.05, 0.1)
			k.light_tint = Color(1.0, 0.9, 0.76)
			k.skyline = ["ruin", "chapel", "ruin"]
			k.clutter = ["crate", "rail", "crate"]
		"cinder_barrens":
			k.paving = 0.25
			k.stone_a = Color(0.3, 0.24, 0.22)
			k.stone_b = Color(0.16, 0.13, 0.13)
			k.earth_a = Color(0.3, 0.17, 0.12)
			k.earth_b = Color(0.12, 0.08, 0.08)
			k.stain = 0.4
			k.wall_stone = Color(0.24, 0.19, 0.18)
			k.flame = Color(1.0, 0.42, 0.12)
			k.ambient = Color(0.72, 0.58, 0.56)
			k.haze = Color(0.14, 0.06, 0.04)
			k.mote = Color(1.0, 0.5, 0.2, 0.75)
			k.light_tint = Color(1.0, 0.86, 0.72)
			k.skyline = ["ruin", "ruin"]
		"gloampine":
			k.paving = 0.3
			k.stone_a = Color(0.26, 0.3, 0.27)
			k.stone_b = Color(0.16, 0.19, 0.19)
			k.earth_a = Color(0.2, 0.22, 0.15)
			k.earth_b = Color(0.1, 0.12, 0.1)
			k.stain = 0.15
			k.wall_stone = Color(0.22, 0.26, 0.25)
			k.flame = Color(0.55, 1.0, 0.6)
			k.ambient = Color(0.52, 0.66, 0.66)
			k.moon = Color(0.55, 0.85, 0.8)
			k.haze = Color(0.05, 0.09, 0.09)
			k.mote = Color(0.6, 0.9, 0.55, 0.5)
			k.shadow_tint = Color(0.03, 0.08, 0.1)
			k.light_tint = Color(0.9, 1.0, 0.9)
			k.skyline = ["ruin", "ruin", "ruin"]
		"salt_choir":
			k.paving = 0.85
			k.stone_a = Color(0.56, 0.54, 0.52)
			k.stone_b = Color(0.36, 0.36, 0.38)
			k.earth_a = Color(0.5, 0.48, 0.46)
			k.earth_b = Color(0.3, 0.3, 0.32)
			k.stain = 0.3
			k.wall_stone = Color(0.46, 0.45, 0.46)
			k.flame = Color(0.8, 0.9, 1.0)
			k.ambient = Color(0.66, 0.68, 0.76)
			k.haze = Color(0.11, 0.11, 0.13)
			k.mote = Color(0.95, 0.95, 0.9, 0.55)
			k.light_tint = Color(0.96, 0.97, 1.0)
			k.skyline = ["chapel", "ruin"]
		"iron_orchard":
			k.paving = 0.6
			k.stone_a = Color(0.3, 0.31, 0.26)
			k.stone_b = Color(0.18, 0.19, 0.18)
			k.earth_a = Color(0.26, 0.22, 0.14)
			k.earth_b = Color(0.13, 0.12, 0.09)
			k.wall_stone = Color(0.25, 0.26, 0.24)
			k.flame = Color(0.95, 0.75, 0.3)
			k.ambient = Color(0.62, 0.66, 0.58)
			k.haze = Color(0.08, 0.09, 0.06)
			k.mote = Color(0.8, 0.8, 0.5, 0.45)
			k.skyline = ["ruin"]
			k.clutter = ["crate", "crate", "rail"]
		"noir_cathedral":
			k.paving = 1.0
			k.tile = 84.0
			k.stone_a = Color(0.28, 0.25, 0.34)
			k.stone_b = Color(0.14, 0.12, 0.19)
			k.stain = 0.35
			k.wall_stone = Color(0.22, 0.19, 0.28)
			k.wall_height = 150.0
			k.flame = Color(0.78, 0.45, 1.0)
			k.ambient = Color(0.54, 0.5, 0.74)
			k.moon = Color(0.7, 0.6, 1.0)
			k.haze = Color(0.07, 0.04, 0.12)
			k.mote = Color(0.7, 0.6, 0.95, 0.45)
			k.shadow_tint = Color(0.08, 0.03, 0.16)
			k.light_tint = Color(0.95, 0.9, 1.0)
			k.skyline = ["chapel", "chapel"]
		"umbral_marches":
			k.paving = 0.35
			k.stone_a = Color(0.24, 0.28, 0.36)
			k.stone_b = Color(0.13, 0.15, 0.22)
			k.earth_a = Color(0.16, 0.19, 0.26)
			k.earth_b = Color(0.08, 0.09, 0.14)
			k.wall_stone = Color(0.2, 0.23, 0.31)
			k.flame = Color(0.5, 0.8, 1.0)
			k.ambient = Color(0.5, 0.58, 0.8)
			k.haze = Color(0.04, 0.06, 0.12)
			k.mote = Color(0.6, 0.7, 0.95, 0.45)
			k.shadow_tint = Color(0.03, 0.05, 0.16)
			k.light_tint = Color(0.88, 0.94, 1.0)
			k.skyline = ["ruin", "ruin"]
			k.clutter = ["rail", "crate"]
		"pale_spire":
			k.paving = 1.0
			k.tile = 90.0
			k.stone_a = Color(0.4, 0.3, 0.3)
			k.stone_b = Color(0.2, 0.13, 0.14)
			k.stain = 0.6
			k.wall_stone = Color(0.3, 0.2, 0.21)
			k.wall_height = 160.0
			k.flame = Color(1.0, 0.2, 0.22)
			k.ambient = Color(0.74, 0.52, 0.56)
			k.moon = Color(1.0, 0.5, 0.5)
			k.haze = Color(0.12, 0.03, 0.05)
			k.mote = Color(1.0, 0.4, 0.3, 0.6)
			k.shadow_tint = Color(0.14, 0.02, 0.06)
			k.light_tint = Color(1.0, 0.88, 0.84)
			k.skyline = ["chapel", "ruin", "ruin"]
		"ashwick":
			k.paving = 0.8
			k.stone_a = Color(0.36, 0.32, 0.3)
			k.stone_b = Color(0.22, 0.2, 0.21)
			k.earth_a = Color(0.3, 0.24, 0.19)
			k.earth_b = Color(0.17, 0.13, 0.12)
			k.stain = 0.05
			k.flame = Color(1.0, 0.68, 0.36)
			k.ambient = Color(0.74, 0.68, 0.7)
			k.haze = Color(0.1, 0.07, 0.08)
			k.vista_dim = 0.72
			k.skyline = []
			k.clutter = []
	return k
