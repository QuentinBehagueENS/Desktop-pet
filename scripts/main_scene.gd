####################################################################################################
##############################               Main Scene               ##############################
####################################################################################################

extends Node2D

#_______________________________________________________________________________/ Variables :

@onready var pet_sprite: AnimatedSprite2D = $DeskPet
@onready var screen_size = Vector2(DisplayServer.screen_get_size(0).x, DisplayServer.screen_get_size(0).y)
@onready var target_position = get_random_position()
@onready var window_state = WindowStates.STILL
@onready var set_target_timer = 0
@onready var set_hidding_timer = 0
@onready var set_teleport_timer = 0
@onready var mouse_last_position = Vector2.ZERO
@onready var throwing_speed = Vector2.ZERO

@export var GRAVITY = Vector2(0, 9)
@export var sprite_size = Vector2(192, 192)
@export var pet_state = PetStates.SPAWN
@export var pet_speed = 120
@export var target_timer_threshold = 13
@export var hidding_timer_threshold = 20
@export var teleport_timer_threshold = 50
@export var taskbar_height = 90

enum PetStates {
	IDLE,
	WALK,
	ASLEEP,
	PANIC,
	FALL,
	SPAWN,
	HIDDING,
	SHOWING_OFF,
	TELEPORT_TO,
	TELEPORT_FROM,
	__NB_PET_STATES__
	}

enum WindowStates {
	STILL,
	MOVING,
	DRAGGED,
	__NB_WIN_STATES
	}

#_______________________________________________________________________________/ Passthrough :

func update_mouse_passthrough():
	var CursorDetection = PackedVector2Array([
		Vector2(0,0),
		Vector2(sprite_size.x, 0),
		Vector2(sprite_size.x, sprite_size.y),
		Vector2(0, sprite_size.y)
		])
	get_window().mouse_passthrough_polygon = CursorDetection

#_______________________________________________________________________________/ Random Target :

func get_random_position():
	var random_x = randf_range(0, screen_size.x - get_viewport_rect().size.x)
	return Vector2(random_x, 0)

func move_towards_target(delta):
	var window_position = Vector2(get_window().position.x, 0)
	var direction = (target_position - window_position).normalized()
	var distance = pet_speed * delta
	if window_position.distance_to(target_position) <= distance:
		window_position = target_position
		window_state = WindowStates.STILL
		pet_state = PetStates.IDLE
		
	else:
		pet_sprite.flip_h = direction.x < 0
		window_position += direction * distance
		pet_state = PetStates.WALK
	get_window().position.x = window_position.x

func set_new_target() :
	target_position = get_random_position()

#_______________________________________________________________________________/ Timer Management :

func update_timers(delta) :
	set_target_timer += delta
	set_hidding_timer += delta
	set_teleport_timer += delta

func is_triggered_target_timer() :
	if set_target_timer >= target_timer_threshold :
		set_target_timer = 0
		return true
	return false

func is_triggered_hidding_timer() :
	if set_hidding_timer >= hidding_timer_threshold :
		set_hidding_timer = 0
		return true
	return false

func is_triggered_teleport_timer() :
	if set_teleport_timer >= teleport_timer_threshold :
		set_teleport_timer = 0
		return true
	return false

#_______________________________________________________________________________/ Gravity :

func is_on_floor() :
	return get_window().position.y + get_window().size.y >= DisplayServer.screen_get_size(0).y - taskbar_height 

#_______________________________________________________________________________/ Start :

func _ready():
	get_window().position.y = screen_size.y - sprite_size.y - taskbar_height
	get_window().position.x = screen_size.x/2 - sprite_size.x/2
	get_window().size.x = sprite_size.x
	get_window().size.y = sprite_size.y
	pet_sprite.play("spawn")
	#modulate = Color(randf_range(0.5,1.2),randf_range(0.5,1.2),randf_range(0.5,1.2))

#_______________________________________________________________________________/ Physics :

func apply_gravity(delta) :
	throwing_speed += GRAVITY * delta*100
	get_window().position.x += throwing_speed.x*delta
	get_window().position.y += throwing_speed.y*delta
	if is_on_floor() :
		get_window().position.y = DisplayServer.screen_get_size(0).y - taskbar_height - get_window().size.y


func _physics_process(delta):
	update_timers(delta)
	if window_state == WindowStates.STILL && !is_on_floor() :
		apply_gravity(delta)
	if window_state == WindowStates.DRAGGED :
		print(1)
		pet_sprite.play("dragged")
		return;
	if is_triggered_target_timer() :
		set_new_target()
	match pet_state :
		PetStates.WALK:
			if pet_sprite.animation != "walk" :
				pet_sprite.play("walk")
			move_towards_target(delta)
			if is_triggered_hidding_timer() :
				pet_state = PetStates.HIDDING
				pet_sprite.play("hidding")
			if is_triggered_teleport_timer() :
				pet_state = PetStates.TELEPORT_TO
				pet_sprite.play("vanish")

		PetStates.IDLE:
			if pet_sprite.animation != "idle" :
				pet_sprite.play("idle")
			move_towards_target(delta)
			if is_triggered_hidding_timer() :
				pet_state = PetStates.HIDDING
				pet_sprite.play("hidding")
			if is_triggered_teleport_timer() :
				pet_state = PetStates.TELEPORT_TO
				pet_sprite.play("vanish")

		PetStates.FALL:
			pass

		PetStates.SPAWN:
			if !pet_sprite.is_playing() :
				pet_state = PetStates.IDLE

		PetStates.HIDDING:
			if !is_on_floor() :
				pet_state = PetStates.IDLE
				pet_sprite.play("idle")
			if !pet_sprite.is_playing() :
				get_window().position.x = get_random_position().x
				pet_state = PetStates.SHOWING_OFF
				pet_sprite.play("showing_off")

		PetStates.SHOWING_OFF:
			if !pet_sprite.is_playing() :
				pet_state = PetStates.IDLE
				pet_sprite.play("idle")
		
		PetStates.TELEPORT_TO:
			if !pet_sprite.is_playing() :
				get_window().position.x = get_random_position().x
				pet_state = PetStates.TELEPORT_FROM
				pet_sprite.play("spawn")

		PetStates.TELEPORT_FROM:
			if !pet_sprite.is_playing() :
				pet_state = PetStates.IDLE
				pet_sprite.play("idle")

#_______________________________________________________________________________/ Inputs :

func _input(_event):
	if Input.is_action_just_pressed("mouse_left") : 
		mouse_last_position = get_global_mouse_position()
	if Input.is_action_pressed("mouse_left") :
		window_state = WindowStates.DRAGGED
		throwing_speed = 5*Vector2 (get_global_mouse_position().x - mouse_last_position.x, get_global_mouse_position().y - mouse_last_position.y)
		#print(throwing_speed)
		get_window().position.x += get_global_mouse_position().x - mouse_last_position.x
		get_window().position.y += get_global_mouse_position().y - mouse_last_position.y
		#clip_window_to_mouse()
	else :
		window_state = WindowStates.STILL
		

''' Switch syntax in GDScript

match x :
	1 : 
		print("1")
	2 :
		print("2")
	_ :
		print("default")
'''
