class_name CrewAgent
extends CharacterBody2D

const MOVE_SPEED := 160.0
const ARRIVAL_THRESHOLD := 4.0

var main: Node2D
var job_role: String = "generalist"

var _destination: Vector2 = Vector2.ZERO
var _has_destination := false
var _current_task: Dictionary = {}
var _is_selected := false

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
        velocity = Vector2.ZERO
        set_physics_process(false)
        if _sprite:
                _sprite.modulate = Color(1, 1, 1)

func initialize(spawn_position: Vector2, main_ref: Node2D) -> void:
        main = main_ref
        global_position = spawn_position
        _destination = spawn_position
        _has_destination = false
        _current_task.clear()
        velocity = Vector2.ZERO
        set_physics_process(true)

func set_selected(selected: bool) -> void:
        _is_selected = selected
        if not _sprite:
                return
        _sprite.modulate = Color(1, 1, 0.6) if selected else Color(1, 1, 1)

func get_job_role() -> String:
        return job_role

func set_destination(world_position: Vector2) -> void:
        _current_task.clear()
        _destination = world_position
        _has_destination = true

func set_task(task_type: String, tile_pos: Vector2i, world_position: Vector2) -> void:
        _current_task = {
                "type": task_type,
                "tile_pos": tile_pos,
                "world_position": world_position,
        }
        _destination = world_position
        _has_destination = true

func _physics_process(delta: float) -> void:
        if not _has_destination:
                velocity = Vector2.ZERO
                move_and_slide()
                return

        var offset := _destination - global_position
        if offset.length() <= ARRIVAL_THRESHOLD:
                global_position = _destination
                velocity = Vector2.ZERO
                _has_destination = false
                _on_arrived_at_destination()
        else:
                velocity = offset.normalized() * MOVE_SPEED
        move_and_slide()

func _on_arrived_at_destination() -> void:
        if _current_task.is_empty():
                return

        var task_type: String = _current_task.get("type", "")
        var tile_pos: Vector2i = _current_task.get("tile_pos", Vector2i.ZERO)

        if task_type.begins_with("build_") and main:
                main.finalize_construction(task_type, tile_pos)
        _current_task.clear()

func cancel_task() -> void:
        _current_task.clear()
        _has_destination = false
        velocity = Vector2.ZERO
