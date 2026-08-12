extends Control

## HUD — displays EXP, Level, Money, and farm notice.
## Reacts to GameState signals; never polls.

@onready var exp_label: Label = %ExpLabel
@onready var level_label: Label = %LevelLabel
@onready var money_label: Label = %MoneyLabel
@onready var notice_label: Label = %NoticeLabel


func _ready() -> void:
	GameState.exp_changed.connect(_on_exp_changed)
	GameState.level_changed.connect(_on_level_changed)
	GameState.money_changed.connect(_on_money_changed)
	GameState.notice_changed.connect(_on_notice_changed)
	# Initial values
	_on_exp_changed(GameState.player_stats.get("exp", 0))
	_on_level_changed(GameState.get_level())
	_on_money_changed(GameState.player_stats.get("money", 0))
	_on_notice_changed(GameState.player_profile.get("notice", ""))


func _on_exp_changed(new_exp: int) -> void:
	exp_label.text = "EXP: %d" % new_exp


func _on_level_changed(new_level: int) -> void:
	level_label.text = "Lv.%d" % new_level


func _on_money_changed(new_money: int) -> void:
	money_label.text = "Coins: %d" % new_money


func _on_notice_changed(text: String) -> void:
	notice_label.text = text
