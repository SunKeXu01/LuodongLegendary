extends Node

signal state_changed

var player_health: int = 100
var player_max_health: int = 100
var player_inner_power: int = 82
var player_max_inner_power: int = 100
var player_experience: int = 36
var player_level: int = 8
var silver: int = 0
var selected_skill: String = "青冥剑式"
var quest_text: String = "清剿云津渡伏兵"
var message: String = "点击地面移动，点击敌人选中并自动迎战。"


func reset() -> void:
	player_health = player_max_health
	player_inner_power = 82
	player_experience = 36
	silver = 0
	selected_skill = "青冥剑式"
	message = "点击地面移动，点击敌人选中并自动迎战。"
	state_changed.emit()


func set_message(value: String) -> void:
	message = value
	state_changed.emit()


func damage_player(amount: int) -> void:
	player_health = maxi(0, player_health - amount)
	state_changed.emit()


func heal_player(amount: int) -> void:
	player_health = mini(player_max_health, player_health + amount)
	state_changed.emit()


func add_silver(amount: int) -> void:
	silver += amount
	state_changed.emit()
