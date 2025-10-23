class_name InputController
extends RefCounted

var main
var crew_manager
var construction_manager
var zone_manager

func _init(main_ref, crew_mgr, construction_mgr, zone_mgr):
        main = main_ref
        crew_manager = crew_mgr
        construction_manager = construction_mgr
        zone_manager = zone_mgr
        _ensure_zone_actions()

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
                elif zone_manager.is_zone_mode_active() and event.button_index == MOUSE_BUTTON_LEFT:
                        if event.is_pressed():
                                zone_manager.begin_paint(_event_to_world(event.position))
                        else:
                                zone_manager.end_paint()
                        main.get_viewport().set_input_as_handled()
                        return
                elif zone_manager.is_zone_mode_active() and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
                        zone_manager.cancel_zone_mode()
                        main.get_viewport().set_input_as_handled()
                        return
                elif event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
                        crew_manager.handle_crew_commands(event, "select_place")
                        main.get_viewport().set_input_as_handled()
                        return
                elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
                        crew_manager.handle_crew_commands(event, "command_cancel")
                        main.get_viewport().set_input_as_handled()
                        return

        if event is InputEventMouseMotion and zone_manager.is_zone_mode_active():
                if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
                        zone_manager.continue_paint(_event_to_world(event.position))
                        main.get_viewport().set_input_as_handled()
                        return

        if event is InputEventKey:
                if not event.is_pressed():
                        return
                if event.is_action_pressed("zone_mode_general"):
                        _enter_zone_mode(main.ZONE_TYPE_GENERAL)
                        return
                if event.is_action_pressed("zone_mode_storage"):
                        _enter_zone_mode(main.ZONE_TYPE_STORAGE)
                        return
                if event.is_action_pressed("zone_mode_industrial"):
                        _enter_zone_mode(main.ZONE_TYPE_INDUSTRIAL)
                        return
                if event.is_action_pressed("zone_mode_clear"):
                        _enter_zone_mode(main.ZONE_TYPE_UNASSIGNED)
                        return
                if event.is_action_pressed("zone_mode_cancel"):
                        zone_manager.cancel_zone_mode()
                        main.get_viewport().set_input_as_handled()
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

func _enter_zone_mode(zone_type: String):
        if main.is_building:
                construction_manager.set_build_mode(false, "")
        zone_manager.start_zone_mode(zone_type)
        main.get_viewport().set_input_as_handled()

func _event_to_world(screen_position: Vector2) -> Vector2:
        return main.game_camera.get_canvas_transform().affine_inverse() * screen_position

func _ensure_zone_actions():
        _register_zone_action("zone_mode_general", KEY_F1)
        _register_zone_action("zone_mode_storage", KEY_F2)
        _register_zone_action("zone_mode_industrial", KEY_F3)
        _register_zone_action("zone_mode_clear", KEY_F4)
        _register_zone_action("zone_mode_cancel", KEY_ESCAPE)

func _register_zone_action(action_name: String, keycode: int):
        if InputMap.has_action(action_name):
                return
        InputMap.add_action(action_name)
        var input_event := InputEventKey.new()
        input_event.physical_keycode = keycode
        InputMap.action_add_event(action_name, input_event)
