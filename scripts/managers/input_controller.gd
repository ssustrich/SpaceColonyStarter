class_name InputController
extends RefCounted

var main
var crew_manager
var construction_manager

func _init(main_ref, crew_mgr, construction_mgr):
        main = main_ref
        crew_manager = crew_mgr
        construction_manager = construction_mgr

func handle_unhandled_input(event):
        if event is InputEventMouseButton:
                if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.is_pressed():
                        main.game_camera.zoom = main.game_camera.zoom * 1.1
                        main.game_camera.zoom = main.game_camera.zoom.clamp(main.CAMERA_ZOOM_MIN, main.CAMERA_ZOOM_MAX)
                        main.get_viewport().set_input_as_handled()
                        return
                elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.is_pressed():
                        main.game_camera.zoom = main.game_camera.zoom / 1.1
                        main.game_camera.zoom = main.game_camera.zoom.clamp(main.CAMERA_ZOOM_MIN, main.CAMERA_ZOOM_MAX)
                        main.get_viewport().set_input_as_handled()
                        return
                elif event.button_index == MOUSE_BUTTON_MIDDLE:
                        main.is_middle_mouse_down = event.is_pressed()
                        if event.is_pressed():
                                main.drag_start_position = event.position
                elif event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
                        crew_manager.handle_crew_commands(event, "select_place")
                        main.get_viewport().set_input_as_handled()
                        return
                elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
                        crew_manager.handle_crew_commands(event, "command_cancel")
                        main.get_viewport().set_input_as_handled()
                        return

        if event is InputEventKey:
                if not event.is_pressed():
                        return
                if event.is_action_pressed("toggle_build"):
                        construction_manager.set_build_mode(not main.is_building, "floor")
                        main.get_viewport().set_input_as_handled()
                        return
                if event.is_action_pressed("toggle_hull_expand"):
                        construction_manager.set_build_mode(not main.is_building, "hull_expand")
                        main.get_viewport().set_input_as_handled()
                        return
                if event.is_action_pressed("toggle_drill_place"):
                        construction_manager.set_build_mode(not main.is_building, "void_drill")
                        main.get_viewport().set_input_as_handled()
                        return

func physics_process(delta):
        _handle_camera_movement(delta)
        if main.is_middle_mouse_down:
                _handle_camera_drag()

func _handle_camera_movement(delta):
        var move_speed = 500 * delta
        var direction = Vector2.ZERO

        if Input.is_action_pressed("ui_right"): direction.x += 1
        if Input.is_action_pressed("ui_left"): direction.x -= 1
        if Input.is_action_pressed("ui_down"): direction.y += 1
        if Input.is_action_pressed("ui_up"): direction.y -= 1

        if direction.length() > 0:
                main.game_camera.global_position += direction.normalized() * move_speed

func _handle_camera_drag():
        var drag_delta = main.drag_start_position - main.get_viewport().get_mouse_position()
        main.game_camera.global_position += drag_delta * main.game_camera.zoom
        main.drag_start_position = main.get_viewport().get_mouse_position()
