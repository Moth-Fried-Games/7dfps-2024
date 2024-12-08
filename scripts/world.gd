extends Node3D

@onready var navigation_region_3d: NavigationRegion3D = $NavigationRegion3D
@onready var dungeon_generator_3d: DungeonGenerator3D = $NavigationRegion3D/DungeonGenerator3D

var player_node: CharacterBody3D = null
var camera_node: Camera3D = null

var dungeon_ready: bool = false
var rooms_ready: bool = false
var navigation_ready: bool = false


func _ready() -> void:
	if is_instance_valid(navigation_region_3d):
		navigation_region_3d.bake_finished.connect(_on_navigation_region_3d_bake_finished)
	if is_instance_valid(dungeon_generator_3d):
		dungeon_generator_3d.done_generating.connect(_on_dungeon_generator_3d_done_generating)
		dungeon_generator_3d.generating_failed.connect(_on_dungeon_generator_3d_generating_failed)
		dungeon_generator_3d.generate()


func _on_dungeon_generator_3d_done_generating() -> void:
	dungeon_ready = true
	navigation_region_3d.bake_navigation_mesh()


func _on_dungeon_generator_3d_generating_failed() -> void:
	dungeon_ready = false
	dungeon_generator_3d.generate()


func _on_navigation_region_3d_bake_finished() -> void:
	navigation_ready = true
