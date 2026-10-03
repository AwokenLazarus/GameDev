class_name StageProp
extends Node2D
## A painted set piece standing on the iso floor. The art is pre-rendered in iso, so it is
## only stood upright and pinned by its footprint.

@onready var art: Sprite2D = $Art
@onready var shadow: Sprite2D = $Shadow


## `foot` is how far down the image the footprint centre sits (0 top, 1 bottom).
func setup(texture: Texture2D, scl: float, foot: float, flat: bool = false) -> void:
	art.texture = texture
	art.offset = Vector2(-texture.get_width() * 0.5, -texture.get_height() * foot)
	IsoView.stand(art, Vector2(scl, scl))
	shadow.visible = not flat
	var reach := texture.get_width() * scl * 0.62
	shadow.scale = Vector2(reach, reach) / 64.0
