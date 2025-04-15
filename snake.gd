extends Node2D

@onready var head: Area2D = %Head
@onready var body: Node2D = %Body
@onready var timer: Timer = $Timer
@onready var score: Label = %Score
@onready var movement_sfx: AudioStreamPlayer2D = $movement_SFX
@onready var dead_sfx: AudioStreamPlayer2D = $dead_SFX
@onready var food_collect_sfx: AudioStreamPlayer2D = $food_collect_SFX

var body_part_scene = preload("res://body_part.tscn")
const FOOD_SCENE = preload("res://food.tscn")

var is_food_in_scene := false
var food_index := -1

var starting_body_count := 5
const BODY_PART_SIZE := 32.0
var body_part_collection : Array[Area2D] = []
var array_of_directions : Array[Vector2] = [Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT]
var moving_direction := Vector2.RIGHT
var disable_input_until_next_step := false
var is_food_spawned_inside_snake := true
var score_i := 0

func _ready() -> void:
	initialize_starting_body()
	timer.timeout.connect(step_the_snake)
	head.area_entered.connect(func(area: Area2D) -> void:
		if area.is_in_group("body_part_group"):
			kill_the_snake()
		if area.is_in_group("food"):
			call_deferred("eat_the_food")
	)

func initialize_starting_body() -> void:
	var random_spawn_direction : Vector2 = array_of_directions.pick_random()
	moving_direction = random_spawn_direction * (-1)
	var viewport_size := get_viewport_rect().size
	var grid_position := Vector2(
		randi_range(starting_body_count, int(viewport_size.x / BODY_PART_SIZE) - 1),
		randi_range(starting_body_count, int(viewport_size.y / BODY_PART_SIZE) - 1)
	)
	head.position.x = grid_position.x * BODY_PART_SIZE + 16.0
	head.position.y = grid_position.y * BODY_PART_SIZE + 16.0
	for count in starting_body_count:
		var new_body_part : Area2D = body_part_scene.instantiate()
		new_body_part.name = "BodyPart" + str(count + 1)
		new_body_part.position = head.position + random_spawn_direction * BODY_PART_SIZE * (count + 1)
		body.add_child(new_body_part)
		body_part_collection.append(new_body_part)
		new_body_part.add_to_group("body_part_group")

func step_the_snake() -> void:
	disable_input_until_next_step = false
	head.position += moving_direction * BODY_PART_SIZE
	body_parts_follow_head()
	movement_sfx.play()

func body_parts_follow_head() -> void:
	var next_body_position := head.position - moving_direction * BODY_PART_SIZE
	wrap_the_snake_head()
	for body_part: Area2D in body_part_collection:
		var position_inter := body_part.position
		body_part.position = next_body_position
		next_body_position = position_inter

func wrap_the_snake_head() -> void:
	var viewport_size := get_viewport_rect().size
	head.position.x = wrapf(head.position.x, 0.0, viewport_size.x)
	head.position.y = wrapf(head.position.y, 0.0, viewport_size.y)

func _process(_delta: float) -> void:
	if disable_input_until_next_step == false:
		process_input()
	if !is_food_in_scene:
		spawn_food()

func spawn_food() -> void:
	var food := FOOD_SCENE.instantiate()
	var viewport_size := get_viewport_rect().size
	var x_grid := int(viewport_size.x / BODY_PART_SIZE)
	var y_grid := int(viewport_size.y / BODY_PART_SIZE)
	food.position.x = randi_range(0, x_grid - 1) * BODY_PART_SIZE
	food.position.y = randi_range(0, y_grid - 1) * BODY_PART_SIZE
	
	food.area_entered.connect(func(area: Area2D) -> void:
		if area.is_in_group("body_part_group"):
			food.position.x = randi_range(0, x_grid - 1) * BODY_PART_SIZE
			food.position.y = randi_range(0, y_grid - 1) * BODY_PART_SIZE
			print("food inside snake")
	)
	add_child(food)
	food_index = food.get_index()
	is_food_in_scene = true

func eat_the_food() -> void:
	food_collect_sfx.play()
	var food = get_child(food_index)
	var body_part := body_part_scene.instantiate()
	body_part.position = body_part_collection[body_part_collection.size() - 1].position
	body_part.add_to_group("body_part_group")
	body_part_collection.append(body_part)
	body.add_child(body_part)
	is_food_in_scene = false
	food.queue_free()
	score_i += 15
	score.text = "Score: " + str(score_i)

func process_input() -> void:
	if Input.is_action_just_pressed("up") and moving_direction != Vector2.DOWN:
		moving_direction = Vector2.UP
		disable_input_until_next_step = true
	if Input.is_action_just_pressed("left") and moving_direction != Vector2.RIGHT:
		moving_direction = Vector2.LEFT
		disable_input_until_next_step = true
	if Input.is_action_just_pressed("down") and moving_direction != Vector2.UP:
		moving_direction = Vector2.DOWN
		disable_input_until_next_step = true
	if Input.is_action_just_pressed("right") and moving_direction != Vector2.LEFT:
		moving_direction = Vector2.RIGHT
		disable_input_until_next_step = true

func kill_the_snake() -> void:
	dead_sfx.play()
	print("dead")
	timer.timeout.disconnect(step_the_snake)
	timer.wait_time = 0.5
	timer.timeout.connect(func() -> void:
		if body.visible:
			body.visible = false
			head.visible = false
		else:
			body.visible = true
			head.visible = true
	)
	var restart_timer := Timer.new()
	add_child(restart_timer)
	restart_timer.wait_time = 3.0
	restart_timer.start()
	restart_timer.timeout.connect(func() -> void:
		get_tree().reload_current_scene()
		print("reload")
	)
