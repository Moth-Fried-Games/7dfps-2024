extends CharacterBody3D

const SPEED: float  = 8.0
const JUMP_VELOCITY: float  = 4.5

@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var placeholder_sprite_3d: Sprite3D = $PlaceholderSprite3D
@onready var melee_ray_cast_3d: RayCast3D = $MeleeRayCast3D
@onready var range_ray_cast_3d: RayCast3D = $RangeRayCast3D
@onready var player_ray_cast_3d: RayCast3D = $PlayerRayCast3D
@onready var melee_timer: Timer = $MeleeTimer
@onready var range_timer: Timer = $RangeTimer
@onready var telegraph_timer: Timer = $TelegraphTimer
@onready var bullet_marker_3d: Marker3D = $PlaceholderSprite3D/BulletMarker3D
@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D

var world_node: Node3D = null
var player_node: CharacterBody3D = null
var camera_node: Camera3D = null
var starting_position: Vector3 = Vector3.INF

var dead: bool = false
@export var health: int = 2
@export var melee: bool = false
@export var ranged: bool = true

var attacking: bool = false
var chasing: bool = false
var player_in_sight: bool = false

func _ready() -> void:
	world_node = get_tree().current_scene
	player_node = world_node.player_node
	camera_node = world_node.camera_node
	if starting_position != Vector3.INF:
		global_position = starting_position
	navigation_agent_3d.velocity_computed.connect(_on_velocity_computed)
	navigation_agent_3d.max_speed = SPEED
	navigation_agent_3d.height = collision_shape_3d.shape.height
	navigation_agent_3d.radius = collision_shape_3d.shape.radius
	if not is_in_group("enemies"):
		add_to_group("enemies")

func shoot_player() -> void:
	var enemy_bullet = GameGlobals.enemy_bullet.instantiate()
	var bullet_target: Vector3 = Vector3()
	if player_node.wish_crouch:
		bullet_target = player_node.global_transform.origin + Vector3(0, 0.5, 0)
	else:
		bullet_target = player_node.global_transform.origin + Vector3(0, 1, 0)
	enemy_bullet.direction = bullet_marker_3d.global_position.direction_to(bullet_target)
	enemy_bullet.starting_position = bullet_marker_3d.global_position
	world_node.add_child(enemy_bullet)

func _physics_process(_delta: float) -> void:
	if player_ray_cast_3d.is_colliding():
		var collided_with := player_ray_cast_3d.get_collider()
		if is_instance_valid(collided_with):
			if collided_with.is_in_group("players"):
				if not player_in_sight:
					navigation_agent_3d.avoidance_enabled = false
					player_in_sight = true
				if not chasing:
					chasing = true
			else:
				if player_in_sight:
					navigation_agent_3d.avoidance_enabled = true
					navigation_agent_3d.target_position = player_node.global_position
					player_in_sight = false
					attacking = false
				if not player_in_sight and navigation_agent_3d.is_navigation_finished():
					navigation_agent_3d.target_position = player_node.global_position
	# Melee Player if close.
	if melee:
		if melee_ray_cast_3d.is_colliding():
			var collided_with := melee_ray_cast_3d.get_collider()
			if is_instance_valid(collided_with):
				if collided_with.is_in_group("players"):
					if not attacking and telegraph_timer.is_stopped() and melee_timer.is_stopped():
						telegraph_timer.start()
						attacking = true
					if attacking and telegraph_timer.is_stopped() and melee_timer.is_stopped():
						attacking = false
						melee_timer.start()
						player_node.process_hit()
	# Shoot if the Player is in sight.
	if ranged:
		if range_ray_cast_3d.is_colliding():
			var collided_with := range_ray_cast_3d.get_collider()
			if is_instance_valid(collided_with):
				if collided_with.is_in_group("players"):
					if not attacking and telegraph_timer.is_stopped() and range_timer.is_stopped():
						telegraph_timer.start()
						attacking = true
					if attacking and telegraph_timer.is_stopped() and range_timer.is_stopped():
						attacking = false
						range_timer.start()
						shoot_player()

	# Make sprite look at camera.
	if camera_node.global_transform.origin != Vector3(0, 1, 0):
		placeholder_sprite_3d.look_at(camera_node.global_transform.origin, Vector3(0, 1, 0))
	if player_node.wish_crouch:
		if player_node.global_transform.origin + Vector3(0, 0.5, 0) != Vector3(0, 1, 0):
			melee_ray_cast_3d.look_at(
				player_node.global_transform.origin + Vector3(0, 0.5, 0), Vector3(0, 1, 0)
			)
			range_ray_cast_3d.look_at(
				player_node.global_transform.origin + Vector3(0, 0.5, 0), Vector3(0, 1, 0)
			)
			player_ray_cast_3d.look_at(
				player_node.global_transform.origin + Vector3(0, 0.5, 0), Vector3(0, 1, 0)
			)
	else:
		if player_node.global_transform.origin + Vector3(0, 1, 0) != Vector3(0, 1, 0):
			melee_ray_cast_3d.look_at(
				player_node.global_transform.origin + Vector3(0, 1, 0), Vector3(0, 1, 0)
			)
			range_ray_cast_3d.look_at(
				player_node.global_transform.origin + Vector3(0, 1, 0), Vector3(0, 1, 0)
			)
			player_ray_cast_3d.look_at(
				player_node.global_transform.origin + Vector3(0, 1, 0), Vector3(0, 1, 0)
			)
	
	if chasing:
		if player_in_sight:
			# Move towards the player.
			var direction := global_position.direction_to(player_node.global_position + Vector3(0,1,0))
			if direction and not attacking:
				velocity.y = direction.y * SPEED
				velocity.x = direction.x * SPEED
				velocity.z = direction.z * SPEED
			else:
				velocity.y = move_toward(velocity.y, 0, SPEED)
				velocity.x = move_toward(velocity.x, 0, SPEED)
				velocity.z = move_toward(velocity.z, 0, SPEED)
			
			move_and_slide()
		else:
			if NavigationServer3D.map_get_iteration_id(navigation_agent_3d.get_navigation_map()) == 0:
				return
			if navigation_agent_3d.is_navigation_finished():
				return
				
			var next_path_position: Vector3 = navigation_agent_3d.get_next_path_position()
			var direction := global_position.direction_to(next_path_position)
			if direction and not attacking:
				velocity.y = direction.y * SPEED
				velocity.x = direction.x * SPEED
				velocity.z = direction.z * SPEED
			else:
				velocity.y = move_toward(velocity.y, 0, SPEED)
				velocity.x = move_toward(velocity.x, 0, SPEED)
				velocity.z = move_toward(velocity.z, 0, SPEED)
			if navigation_agent_3d.avoidance_enabled:
				navigation_agent_3d.set_velocity(velocity)
			else:
				_on_velocity_computed(velocity)

func _on_velocity_computed(safe_velocity: Vector3):
	velocity = safe_velocity
	move_and_slide()

func process_hit() -> void:
	if not dead:
		health -= 1
		if health <= 0:
			dead = true
			UiMain.ui_player.decrease_stress(1)
			queue_free()
