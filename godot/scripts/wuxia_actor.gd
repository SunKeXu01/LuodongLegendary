class_name WuxiaActor
extends CharacterBody2D

signal defeated(actor: WuxiaActor)

@export var display_name: String = "江湖客"
@export var hostile: bool = false
@export var max_health: int = 100
@export var move_speed: float = 155.0

var health: int
var selected := false
var moving := false
var combat_target: WuxiaActor
var attack_cooldown := 0.0
var destination := Vector2.ZERO
var agent: NavigationAgent2D


func _ready() -> void:
	health = max_health
	agent = NavigationAgent2D.new()
	agent.path_desired_distance = 8.0
	agent.target_desired_distance = 10.0
	agent.radius = 18.0
	agent.max_speed = move_speed
	add_child(agent)
	queue_redraw()


func command_move(target: Vector2) -> void:
	destination = target
	agent.target_position = target
	moving = true


func stop() -> void:
	moving = false
	velocity = Vector2.ZERO


func take_damage(amount: int) -> void:
	health = maxi(0, health - amount)
	queue_redraw()
	if health == 0:
		defeated.emit(self)


func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if not moving or agent.is_navigation_finished():
		stop()
		return
	var next_position := agent.get_next_path_position()
	var direction := global_position.direction_to(next_position)
	velocity = direction * move_speed
	move_and_slide()
	queue_redraw()


func _draw() -> void:
	# Soft ground shadow and selection ring keep actors readable over the painted map.
	draw_ellipse(Vector2(0, 17), Vector2(23, 9), Color(0.03, 0.025, 0.02, 0.45))
	if selected:
		draw_arc(Vector2(0, 16), 27.0, 0.0, TAU, 48, Color("#e7c46a"), 3.0)

	var robe := Color("#263f39") if not hostile else Color("#42252b")
	var robe_light := Color("#4f7766") if not hostile else Color("#8a3d3d")
	var trim := Color("#d5bb72") if not hostile else Color("#c68b55")
	draw_polygon(
		PackedVector2Array([
			Vector2(-15, -4), Vector2(15, -4), Vector2(21, 22),
			Vector2(8, 28), Vector2(-9, 28), Vector2(-21, 22)
		]),
		PackedColorArray([robe, robe_light, robe, robe, robe_light, robe])
	)
	draw_line(Vector2(-13, 6), Vector2(14, 6), trim, 3.0)
	draw_line(Vector2(-3, -3), Vector2(-3, 23), trim.darkened(0.25), 2.0)
	draw_circle(Vector2(0, -17), 10.5, Color("#d2a378"))
	draw_arc(Vector2(0, -17), 10.5, PI, TAU, 20, Color("#211b1b"), 6.0)
	draw_line(Vector2(-7, -25), Vector2(7, -25), Color("#201b1c"), 5.0)
	draw_line(Vector2(14, 3), Vector2(27, -13), Color("#d8d0b1"), 3.0)
	draw_line(Vector2(25, -15), Vector2(31, -21), Color("#82643f"), 4.0)

	if hostile and health > 0:
		draw_rect(Rect2(-27, -43, 54, 6), Color(0.08, 0.06, 0.05, 0.9), true)
		draw_rect(
			Rect2(-25, -41, 50.0 * float(health) / float(max_health), 2),
			Color("#bd443b"),
			true
		)


func draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
