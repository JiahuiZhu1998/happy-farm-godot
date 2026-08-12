## CropDefinition
## Immutable data resource describing a crop type.
## One .tres file per crop in res://data/crops/.
class_name CropDefinition
extends Resource

@export var crop_id: int = 0
@export var display_name: String = ""
@export var stage_count: int = 3
## Duration in seconds for each growth stage (not cumulative).
## Length must equal stage_count.
@export var stage_durations: Array[float] = []
## One texture per growth stage. Length must equal stage_count.
@export var stage_textures: Array[Texture2D] = []
@export var seed_texture: Texture2D
@export var planted_texture: Texture2D
@export var harvested_texture: Texture2D
@export var seed_price: int = 10
@export var sell_price: int = 20
@export var required_level: int = 0
