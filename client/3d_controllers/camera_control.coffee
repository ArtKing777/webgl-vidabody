
main_view = require '../views/main_view'
{show_tutorial, close_tutorial, hide_tutorial} = require '../views/tutorials'
{mat3, mat4, vec2, vec3, vec4, quat} = require 'gl-matrix-2-2'

# Modes
IDLE = 0
TB_ROTATING = 1 #Trackball rotation
TT_ROTATING = 2 #Turntable rotation
ZOOMING = 3
PANNING = 4
TILTING = 5
SPACESHIP = 6
AUTOPILOT = 7
AUTO_BREAKABLE = 8 # same as AUTOPILOT but breaks by user interaction
OSCC_DISPLACEMENT = 9

VEC3_0 = new Float32Array([0,0,0])
VEC3_05 = new Float32Array([.5,.5,.5])

MIN_DISTANCE = 0.002

# Hack for nullifying un-rotate Z
molecular_scenes_checkbox = null
micro_scenes_checkbox = null

camera_control = null
snap_helper = null

# fix for keys_pressed in engine.js
# keys_pressed will be not changed if ctrl or meta key are pressed.
# otherwise after releasing, for instance, ctrl + A, A button will be still
# registered as pressed, so camera will infinite go away
window.addEventListener 'load', ->
    mouse["ignore_ctrl"] = true

init_camera_control = ->
    exports.camera_control = camera_control = new CameraControl()
    camera_control.init()
    snap_helper = new SnapHelper()



class CameraState
    constructor: (camera, level) ->
        @camera = camera
        @scene = camera.scene
        @viewport = null
        # Level is an int that decides the order of drawing
        # and when to clear the depth buffer(when level changes)
        @level = level

        # Automation
        @origin_position = vec3.create()
        @origin_rotation = quat.create()
        @origin_distance = 0
        @target_position = vec3.create()
        @target_rotation = quat.create()
        @target_distance = 0
        @init_time = 0
        @duration = 0

        # Transformation matrices from/to current scene
        @matrix_to_current = mat4.create()
        @matrix_from_current = mat4.create()
        @quat_from_current = quat.create() #rotation part of matrix_from_current

        # To use in get_state
        @ob_name = ''
        @scene_name = ''
        # These can be extracted from matrix
        @point = vec3.create()
        @normal = vec3.create()
        @scale = 1

        @v = vec3.create() # temp

        @easing = true

    tick: (now, frame_duration) ->
        if not scene.enabled
            # Freeze transition when not rendering
            @init_time += frame_duration
            return
        is_current = this == camera_control.current_camera_state
        rel_t = (now - @init_time)/@duration
        f = min(1, rel_t)
        if @easing
            f = (-Math.cos((-Math.cos(f*Math.PI)+1)*0.5*Math.PI)+1)*0.5
        distance = @target_distance*f + @origin_distance*(1-f)
        if is_current
            camera_control.last_ray.distance = distance # in case it's interrumpted
        cam_pos = @camera.position
        cam_rot = @camera.rotation
        quat.slerp(cam_rot, @origin_rotation, @target_rotation, f)
        vec3.lerp(cam_pos, @origin_position, @target_position, f)
        # at this point, 'cam_pos' is actually the target
        # so we use it to assign the ray point and orbit point
        if is_current
            vec3.copy(camera_control.last_ray.point, cam_pos)
            vec3.copy(camera_control.orbit_point, cam_pos)
        # origin_position and target_position are positions of the target,
        # not the camera; we need to add the distance
        v = vec3.set(@v, 0, 0, distance)
        vec3.transformQuat(v, v, cam_rot)
        vec3.add(cam_pos, cam_pos, v)
        # Return true if finished, to stop autopilot
        return rel_t >= 1

    clone: ->
        clone = new CameraState(@camera, @level)
        for attr of this
            a = @[attr]
            if a?.set?
                clone[attr].set(a)
            else
                clone[attr] = a
        clone


exports.toggle_oscc = ->
    oscc = $("#control_toolbar")[0]
    oscc.classList.toggle('hidden')
    close_tutorial('oscc_button')
    main_view.render_all_views()



class CameraControl
    constructor: () ->
        # CameraStates
        @current = null
        @others = []
        @tutorial_trigger_time = 0
        @pointer = {
            'elm':$("#pointer")[0],
            'point':[0,0]
            }
        @zoom_slider_position = 50
        @oscc = $("#control_toolbar")[0]
        oscc_width = 64
        x = @oscc.x = 100 - ((20 - oscc_width/2 + 128) / render_manager.width) * 100
        y = @oscc.y = (0 / render_manager.height) * 100
        @oscc.style.left = x+'%'
        @oscc.style.top = y+'%'
        if window.is_pearson and (window.load_tour_hash or window.load_tour_uuid)
            @oscc.classList.add('hidden')
        else
            @oscc.classList.remove('hidden')
        @zoom_slider = $('#zoom_slider')[0]
        @zoom_action = $('#zoom_action')[0]
        @pan_action = $('#pan_action')[0]
        @tilt_button = $('#tilt')[0]
        @using_oscc = false
        @using_oscc_time = 0


    init: () ->
        app = find_app_root() # NOTE: actually this is the canvas container!
        app.addEventListener('mousemove', () -> main_loop.reset_timeout())
        main_loop.reset_timeout()
        @selected_mode = TB_ROTATING
        @tick = @tick.bind(this)
        scene.pre_draw_callbacks.append(@tick)


        # ON MOUSE DOWN
        # CHANGE MODE
        # LOCK CURSOR in some cases
        # CHANGE CURSOR
        # Locking hides the cursor but it may not be
        # enabled, accepted, or supported at all(msie)

        mousedown = (event) =>
            # For freeing hack for uservoice's screenshot
            if uservoice_hack
                $('#canvas_container')[0].style.background = 'none'
                render_manager.canvas.visibility = 'visible'
                window.uservoice_hack = false

            # Avoid user control in landing tour
            # not, That should be allowed
            # if tour_viewer.is_viewing() and tour_viewer.is_landing
            #     return

            main_loop.reset_timeout()
            if @mode == IDLE
                left = event.button == 0 and not event.ctrlKey
                middle = event.button == 1 and not event.ctrlKey
                # Mac MMB+ctrl means RMB, but here we're also accepting
                # LMB+ctrl as synonymous of RMB
                right = event.button == 2 or event.ctrlKey

                vec3.copy(@orbit_point, @last_ray.point)

                if left
                    @mode = TB_ROTATING
                    if event.target.id == 'pan'
                        # app.requestPointerLock?()
                        @mode = PANNING
                        @pan_scale = @last_ray.distance or @pan_scale
                        @invert_pan = @invert_pan_widget
                        @using_oscc = true

                    else if event.target.id == 'rotate'
                        # app.requestPointerLock?()
                        @mode = TT_ROTATING
                        @using_oscc = true

                    else if event.target.id == 'zoom'
                        # app.requestPointerLock?()
                        @mode = ZOOMING
                        @using_oscc = true

                    else if event.target.id == 'tilt'
                        # app.requestPointerLock?()
                        @mode = TILTING
                        @using_oscc = true

                    else if event.target.id == 'handle'
                        @mode = OSCC_DISPLACEMENT
                        @using_oscc = false
                        # app.requestPointerLock?()

                    else
                        # app.requestPointerLock?()


                else if right
                    @mode = PANNING
                    @pan_scale = @last_ray.distance or @pan_scale
                    @invert_pan = @invert_pan_mmb
                    # app.requestPointerLock?()

                else if middle
                    @mode = SPACESHIP
                    # app.requestPointerLock?()
            window.addEventListener('mouseup', mouseup)

        mouseup = (event) =>
            if @is_user_moving_camera() and mouse.movement_since_mousedown > 0
                tour_editor.save_state(700)
            window.removeEventListener('mouseup', mouseup)
            if @mode != AUTOPILOT
                @mode = IDLE
                @autopilotCallback = null
            @using_oscc = false
            document.exitPointerLock?()
            #@oscc.classList.remove('hidden')
            app.style.cursor = ''
            # Make the 'restore view' button appear
            if mouse.movement_since_mousedown > 0
                tour_viewer.set_modified_view()

        document.body.addEventListener 'mouseleave', (e) ->
            if e.target == document.body and @mode == OSCC_DISPLACEMENT
                @mode = 0
        , true

        last_dist = 0
        delta_dist = 0
        touch_zooming = false

        app.addEventListener('mousedown', mousedown)

        app.addEventListener 'touchstart', (event) =>
            event.preventDefault()
            @invert_pan_mmb = true
            if event.targetTouches.length == 1
                mouseup()
                ported_mousemove(event.targetTouches[0])
                mouse.rel_x = mouse.rel_y = 0
                mousedown {button:0, target:event.target}
            else if event.targetTouches.length == 2
                mouseup()
                ported_mousemove(event.targetTouches[0])
                mouse.rel_x = mouse.rel_y = 0
                mousedown {button:2, target:event.target}
                t0 = event.targetTouches[0]
                t1 = event.targetTouches[1]
                x = t1.pageX - t0.pageX
                y = t1.pageY - t0.pageY
                last_dist = Math.sqrt(x*x + y*y)
                delta_dist = 0
                touch_zooming = false


        touchend = (event) ->
            mouseup()
        app.addEventListener('touchend', touchend)
        app.addEventListener('touchleave', touchend)
        app.addEventListener('touchcancel', touchend)

        app.addEventListener 'touchmove', (event) =>
            event.preventDefault()
            if event.targetTouches.length == 1
                t = event.targetTouches[0]
                ported_mousemove(t)
            else if event.targetTouches.length == 2
                t0 = event.targetTouches[0]
                t1 = event.targetTouches[1]
                x = t1.pageX - t0.pageX
                y = t1.pageY - t0.pageY
                dist = Math.sqrt(x*x + y*y)
                delta_dist += dist-last_dist
                console.log [dist|0, delta_dist|0]
                last_dist = dist
                if Math.abs(delta_dist) > 50
                    touch_zooming = true
                if touch_zooming
                    @touch_zoom += delta_dist * -3 / render_manager.height
                    delta_dist = 0
                else
                    # panning
                    ported_mousemove(t0)



        # This is a copy of the engine's mousemove to
        # simulate mousemove with the touch events above
        ported_mousemove = (event) ->
            if mouse.any_button
                return
            x = event.pageX
            y = event.pageY
            rel_x = x - mouse.page_x
            rel_y = y - mouse.page_y
            mouse.page_x = x
            mouse.page_y = y
            mouse.rel_x += rel_x
            mouse.rel_y += rel_y
            mouse.x += rel_x
            mouse.y += rel_y
            mouse.target = event.target


        # CAMERA CONTROL STATE

        @last_position = vec3.create()
        @last_rotation = vec4.create()
        @last_ray = {'point': vec3.create(), 'distance': 1}
        @mode = IDLE
        @pan_scale = 1
        @orbit_point = vec3.create()

        @rot = vec3.create()
        @pan = vec3.create()
        @ship_rot = vec3.create()
        @ship_move = vec3.create()
        @min_distance_smoothed = 1
        @touch_zoom = 0

        @current_camera_state = new CameraState(objects.Camera, 0)
        @camera_states = [@current_camera_state]
        @autopilotCallback = null
        @pre_pause_autopilotCallback = null
        @paused = false
        @pre_pause_mode = IDLE
        @paused_states = null
        @pre_pause_camera_state_idx = 0

        # SETTINGS
        @rotate_speed = 8
        @pan_speed = 1
        @zoom_fac = 0.1
        @zoom_in_sp = 0.8
        @smoothing = 6
        @ship_rotate_speed = 1
        @ship_tilt_speed = 1
        @ship_rot_smooth = 3
        @ship_accel = 1
        @ship_max_speed = 3
        @invert_pan = false
        @invert_pan_widget = false
        @invert_pan_mmb = false
        @invert_pan_upright = false
        @upright_sq_distance = 10000000
        @upright_smooth = 1

        # ELEMENTS
        @tilt_element = app.querySelector('#tilt')

        # Temporary vars
        @q = quat.create()
        @u = vec3.create()
        @v = vec3.create()
        @v2 = vec3.create()
        @m3 = mat3.create()

        @wheel_maximize = 0
        @wheel_save_timer = null

    add_camera_settings: (gui) ->
        gui.remember(this)
        folder = gui.addFolder('Camera control')
        folder.add(this, 'rotate_speed', 0, 20)
        folder.add(this, 'pan_speed', 0, 6)
        folder.add(this, 'zoom_fac', 0, 1)
        folder.add(this, 'zoom_in_sp', 0, 1)
        folder.add(this, 'smoothing', 0, 16)
        folder.add(this, 'ship_rotate_speed', 0, 4)
        folder.add(this, 'ship_tilt_speed', 0, 4)
        folder.add(this, 'ship_rot_smooth', 0, 16)
        folder.add(this, 'ship_accel', 0, 10)
        folder.add(this, 'ship_max_speed', 0, 10)
        folder.add(this, 'invert_pan_widget')
        folder.add(this, 'invert_pan_mmb')
        folder.add(this, 'invert_pan_upright')
        folder.add(this, 'upright_sq_distance', 0, 8)
        folder.add(this, 'upright_smooth', 0, 8)

    save_state: () =>
        # to be called in the wheel_save_timer timeout
        tour_editor.save_state(true) # saving twice anyway
        @wheel_save_timer = null

    save_state_later: () ->
        clearTimeout(@wheel_save_timer)
        @wheel_save_timer = setTimeout(@save_state, 500)

    is_user_zooming: ->
        @wheel_save_timer

    is_user_moving_camera: ->
        # TODO more modes here?
        (camera_control.mode != IDLE) and (camera_control.mode != AUTOPILOT) and (camera_control.mode != AUTO_BREAKABLE) and (camera_control.mode != OSCC_DISPLACEMENT)

    pause: ->
        if not @paused and (camera_control.mode == AUTOPILOT or camera_control.mode == AUTO_BREAKABLE)
            @paused = true
            @pre_pause_mode = @mode
            @pre_pause_camera_state_idx = @camera_states.indexOf @current_camera_state
            @pre_pause_autopilotCallback = @autopilotCallback
            @mode = IDLE
            now = performance.now()
            @paused_states = for cs in @camera_states
                # Storing elapsed time in init_time
                clone = cs.clone()
                clone.init_time = now - clone.init_time
                clone
        return

    resume: ->
        if @paused
            @paused = false
            @mode = @pre_pause_mode
            @autopilotCallback = @pre_pause_autopilotCallback
            now = performance.now()
            @camera_states = @paused_states
            for cs in @camera_states
                # See pause()
                cs.init_time = now - cs.init_time
            @current_camera_state = @camera_states[@pre_pause_camera_state_idx]
        return

    reset_intertia: ->
        @rot[0] = @rot[1] = @rot[2] = 0
        @pan[0] = @pan[1] = @pan[2] = 0
        @ship_rot[0] = @ship_rot[1] = @ship_rot[2] = 0
        @ship_move[0] = @ship_move[1] = @ship_move[2] = 0
        return

    tick: (scene, frame_duration) ->

        ## TUTORIAL TRIGGERING START

        block_tutorials = tour_viewer.is_viewing() or not login_panel.closed
        if not block_tutorials
            @tutorial_trigger_time += frame_duration

        moving = mouse.movement_since_mousedown >= CLICK_MOVEMENT_THRESHOLD
        if @using_oscc and moving
            @using_oscc_time += frame_duration

        render_views = false
        achievements['oscc'] = @using_oscc_time > 1000

        if @tutorial_trigger_time > 5000
            if not achievements['main_menu'] and not block_tutorials
                show_tutorial('main_menu')
            else if achievements['main_menu']
                close_tutorial('main_menu')

        if @tutorial_trigger_time > 20000
            if not achievements['login_panel'] and not block_tutorials
                show_tutorial('login_panel')

            else if achievements['login_panel']
                close_tutorial('login_panel')

        if achievements['oscc']
            close_tutorial('oscc')
        else if not block_tutorials
            show_tutorial('oscc')

        if block_tutorials
            hide_tutorial('oscc')
            hide_tutorial('main_menu')
            hide_tutorial('login_panel')

        ## TUTORIALS TRIGGERING END

        ###
        # This is the real beginning of the camera_control tick function
        # It prepares some common variables, then proceeds to
        # check camera mode
        ###

        cam = @current_camera_state.camera
        scene = cam.scene
        height_inverse = 1/render_manager.height
        half_height = render_manager.height * 0.5
        half_width = render_manager.width * 0.5
        center_x = mouse.x - (half_width)
        center_y = mouse.y - (half_height)
        frame_duration_seconds = frame_duration * 0.001
        smoothing = @smoothing * frame_duration_seconds
        # temporary vars used thorough the function
        v = @v
        u = @u
        q = @q
        m3 = @m3

        # Fixes Firefox's(and in some cases Chrome's) mouse-locked-after-accept bug
        if mouse.lock_element and not mouse.any_button
            document.exitPointerLock?()

        last_position = vec3.copy(@last_position, cam.position)
        last_rotation = vec4.copy(@last_rotation, cam.rotation)

        if @mode == AUTOPILOT or @mode == AUTO_BREAKABLE
            now = performance.now()
            # for cs in @camera_states
            #     finished = cs.tick(now, frame_duration)
            finished = @camera_states[0].tick(now, frame_duration)
            # All states finish at the same time
            if finished
                @mode = IDLE
                @autopilotCallback?()
            main_loop.reset_timeout()
        else
            # IF IT'S NOT ON AUTOPILOT,
            # ALL TRANSFORMATIONS ARE APPLIED ALL THE TIME HERE
            # TO SHOW SMOOTH MOVEMENTS

            is_main_scene = @current_camera_state.level == 0 and
                not micro_scenes_checkbox?.classList.contains('checkbox-half') and
                not molecular_scenes_checkbox?.classList.contains('checkbox-half')

            # Camera rays
            # ray_ratio=0 means in the border, 0.5 in the center
            ray_ratio = 0.1
            main_ray = pick_object_f(0.5, 0.5, 5)
            if main_ray and not @camera_states[1]
                # If point is off screen, set it to the last ray instead
                # (which is set during autopilot)
                # It can only happen with gl_raytest (breaking micro scene transitions)
                vec3.transformMat4(v, main_ray.point, render_manager._world2cam)
                q[0] = v[0]
                q[1] = v[1]
                q[2] = v[2]
                q[3] = 1
                vec4.transformMat4(q, q, cam.projection_matrix)
                if Math.abs(q[0]) >= 1 or Math.abs(q[1]) >= 1
                    main_ray = @last_ray
            else
                if @camera_states[1]
                    vec3.copy @last_ray.point, @camera_states[1].point
                main_ray = @last_ray
                # Set distance to the actual distance to camera
                main_ray.distance = vec3.distance(cam.position, main_ray.point)
            distance = main_ray.distance

            left_ray = pick_object_f(ray_ratio, 0.5)
            right_ray = pick_object_f(1-ray_ratio, 0.5)
            top_ray = pick_object_f(0.5, ray_ratio)
            bottom_ray = pick_object_f(0.5, 1-ray_ratio)
            min_distance_all_rays = min(
                left_ray and left_ray.distance or Infinity,
                right_ray and right_ray.distance or Infinity,
                top_ray and top_ray.distance or Infinity,
                bottom_ray and bottom_ray.distance or Infinity,
                main_ray.distance
            )


            # CAMERA ROTATE-AROUND MODES

            # Each smoothed variable is added a value when the user
            # interacts, then lerp_remainder smoothes out the result
            # NOTE: lerp_remainder mutates rot
            rot = @rot
            show_center = false
            if @mode == TB_ROTATING
                rs = height_inverse * -@rotate_speed
                trackball_rotation(rot, center_x, center_y,
                    mouse.rel_x, mouse.rel_y, render_manager.diagonal * 0.5, rs)
                show_center = true
            else if @mode == TT_ROTATING
                rs = height_inverse * -@rotate_speed
                turntable_rotation(rot, center_x, center_y, mouse.rel_x, mouse.rel_y, render_manager.diagonal * 0.5, rs)
                show_center = true
            else if @mode == TILTING
                rot[2] += tilt_rotation(center_x, center_y,
                    mouse.rel_x*0.5, mouse.rel_y*0.5)

            # If too far, un-rotate Z
            squared_distance_to_vertical = cam.position[0] ** 2 + cam.position[1] ** 2
            # far_distance = squared_distance_to_vertical > @upright_sq_distance
            # far_distance = far_distance and is_main_scene
            far_distance = false
            if far_distance
                @tilt_button.classList.add('hidden')
                vec3.set(@v2, 0, 0, vec3.distance(cam.position, @orbit_point))
                # To keep looking at the same point, move to the pivot
                vec3.transformQuat(v, @v2, cam.rotation)
                vec3.sub(cam.position, cam.position, v)
                mat3.fromQuat(m3, cam.rotation)
                vec3.set(u, m3[1], m3[4], m3[7]) # what we have
                vec3.set(v, 0, 0, 1) # what we want
                quat.rotationTo(q, u, v)
                quat.mul(q, q, cam.rotation)
                quat.slerp(cam.rotation, cam.rotation, q, frame_duration_seconds * @upright_smooth)
                # Move the camera back to the previous distance
                vec3.transformQuat(v, @v2, cam.rotation)
                vec3.add(cam.position, cam.position, v)
                # Vertical drag = pan Z
                this.pan[1] += rot[0] * 0.1 * (@invert_pan_upright*-2 +1)


                # Nullify user's X and Z rotation
                rot[0] = rot[2] = 0
            else
                @tilt_button.classList.remove('hidden')
            lerp_remainder(v, rot, smoothing)
            rotate_around(cam, @orbit_point, v)



            # PAN AND ZOOM
            pan = @pan
            if @mode == PANNING
                @pan_action.classList.remove('hidden')
                show_center = true
                ps = height_inverse * @pan_scale * @pan_speed
                invert = @invert_pan*-2 +1
                pan[0] += mouse.rel_x * ps * invert
                pan[1] += mouse.rel_y * -ps * invert
            else
                @pan_action.classList.add('hidden')

            # The pan vector is used also for zooming
            if @mode == ZOOMING
                rel = min(max(mouse.rel_y,-10),10)
                @zoom_action.classList.remove('hidden')
                zoom = rel * 0.03 * distance * @zoom_fac

            else
                rel = 0
                zoom = 0
                @zoom_action.classList.add('hidden')


            new_slider_position = (rel/10)*50 + 50
            f = @zoom_slider_position + (new_slider_position - @zoom_slider_position)*0.09
            @zoom_slider.style.top = f +  '%'
            @zoom_slider.style['border-radius'] = (abs(f - 50)/4 + 3) + 'px'
            @zoom_slider.style.height = (40 - abs(f - 50)/2.5) + 'px'
            @zoom_slider.style['margin-top'] = (-20 + (abs(f - 50)/2.5)) + 'px'

            @zoom_slider_position = f

            zoom += mouse.wheel * @zoom_fac
            zoom += (keys_pressed[KEYS.S] - keys_pressed[KEYS.W]) * frame_duration * 0.0014
            zoom += @touch_zoom
            @touch_zoom = 0
            if distance < 3 or zoom < 0
                pan[2] += zoom
                if zoom
                    @save_state_later()
                    @pan_scale = distance
                    if not tour_viewer.modified_view
                        tour_viewer.set_modified_view()

            if zoom < 0 and not tour_editor.editing
                pan[2] *= distance
                pan[2] = min(0, max(distance + pan[2], MIN_DISTANCE) - distance)
                pan[2] /= distance

            lerp_remainder(v, pan, smoothing)
            v[2] *= distance
            vec3.transformQuat(v, v, cam.rotation)
            vec3.add(cam.position, cam.position, v)

            # SPACESHIP MODE KEYS

            key_tilt_left = keys_pressed[KEYS.Q]
            key_tilt_right = keys_pressed[KEYS.E]
            key_forward = 0 # keys_pressed[KEYS.W]
            key_reverse = 0 # keys_pressed[KEYS.S]
            key_right = keys_pressed[KEYS.D]
            key_left = keys_pressed[KEYS.A]

            if key_tilt_left | key_tilt_right | key_forward | key_reverse | key_right | key_left
                if not tour_viewer.modified_view
                    tour_viewer.set_modified_view()

            # SPACESHIP ROTATION
            ship_rot = @ship_rot
            if @mode == SPACESHIP
                ps = height_inverse * -@ship_rotate_speed
                ship_rot[0] += mouse.rel_x * ps
                ship_rot[1] += mouse.rel_y * ps
                show_center = true
            ship_rot[2] += (key_tilt_left - key_tilt_right) * frame_duration_seconds * @ship_tilt_speed
            if ship_rot[2] > 1000000
                vec3.set(ship_rot,0,0,0)
                return

            lerp_remainder(v, ship_rot, @ship_rot_smooth * frame_duration_seconds)

            quat.set(q, 0, 0, 0, 1)
            quat.rotateY(q, q, v[0])
            quat.rotateX(q, q, v[1])
            quat.rotateZ(q, q, v[2])
            # swapping quat.mul operands is local space
            quat.mul(cam.rotation, cam.rotation, q)

            # SPACESHIP MOVEMENT
            # First we determine the speed by smoothing the side rays
            # but not the main one
            min_dist_smoothing = frame_duration_seconds * 0.5  # 2-second smooth
            @min_distance_smoothed *= 1 - min_dist_smoothing
            @min_distance_smoothed += min_distance_all_rays * min_dist_smoothing
            distance_speed = min(@min_distance_smoothed, distance)

            # Then we calculate the acceleration vector
            v[0] = key_right - key_left
            v[1] = 0
            v[2] = key_reverse - key_forward
            vec3.normalize(v, v)
            vec3.scale(v, v, @ship_accel * distance_speed)

            # Adding it to the main smoothed vector, which then moves the camera
            ship_move = @ship_move
            vec3.add(ship_move, ship_move, v)
            lerp_remainder(v, ship_move, smoothing)
            vec3.transformQuat(v, v, cam.rotation)
            vec3.scale(v, v, frame_duration_seconds)
            vec3.add(cam.position, cam.position, v)


            # CHANGE THE ORBIT POINT
            # When it's far, when panning or when moving in the spaceship
            if far_distance
                # Move to center
                @orbit_point[0] *= 0.5
                @orbit_point[1] *= 0.5
                # limit to -0.9...0.9
                @orbit_point[2] = min(visible_area.max[2],max(visible_area.min[2],@orbit_point[2]))
            else if @mode == PANNING or @mode == SPACESHIP
                vec3.copy(@orbit_point, main_ray.point)
            # It also changes when the user starts rotating
            # or during autopilot

            if show_center
                @pointer.elm.style.opacity = '1'
            else
                @pointer.elm.style.opacity = '0'


            # ROTATION CENTER POINTER
            p = @pointer.point
            n = frame_duration_seconds * 60
            d = 0.3
            #On each frame, p is displaced <d> times the distance from <p> to <main_ray.point>
            d = 1 - Math.pow(d,n) * Math.pow(1/d-1,n) #fps independence interpolation formula
            ps = point3d_to_screen(@orbit_point)
            vec2.lerp(p, p, ps, d)
            @pointer.elm.style.left = p[0]* 100 + '%'
            @pointer.elm.style.top = p[1]* 100 + '%'

            # ROTATION CENTER 3D WIDGET
            # Using 'd' (smooth factor) from the previous section
            ob = objects.rot_center
            if ob and(@mode == TB_ROTATING or @mode == TT_ROTATING)
                vec3.lerp(ob.scale, ob.scale, VEC3_05, d)
                obr = quat.create()
                quat.rotateX(obr, obr, mouse.rel_y * 0.01)
                quat.rotateY(obr, obr, mouse.rel_x * 0.01)
                quat.mul(ob.rotation, obr, ob.rotation)
            else if ob
                vec3.lerp(ob.scale, ob.scale, VEC3_0, d)


            # Look at the orbit point when the camera is rotating and not looking to the orbit point.
            if @mode == TB_ROTATING or @mode == TT_ROTATING

                a = vec3.transformQuat(v, VECTOR_MINUS_Z, cam.rotation)
                b = vec3.sub(@v2,@orbit_point, cam.position)
                vec3.normalize(b, b)
                d = abs(vec3.sqrDist(a,b))*0.5

                if d > 0.0000001 and moving
                    lookat(cam,@orbit_point,'Y','-Z',0.93,frame_duration_seconds)


            if @mode == OSCC_DISPLACEMENT
                @oscc.x += mouse.rel_x * 100 / render_manager.width
                @oscc.y += mouse.rel_y * 100 / render_manager.height
                @oscc.style.left = @oscc.x + '%'
                @oscc.style.top = @oscc.y + '%'



            is_pos_changed = vec3.squaredDistance(last_position, objects.Camera.position) != 0
            is_rot_changed = vec4.squaredDistance(last_rotation, objects.Camera.rotation) != 0

            if is_pos_changed or is_rot_changed
                main_loop.reset_timeout()

            # LAST OF ALL, SAVE RAY
            @last_ray = main_ray

        # INSTANCE/DESTROY MICRO SCENES WHEN NOT ON AUTOPILOT
        if @mode != AUTOPILOT
            update_micro_scenes([main_ray]) #, left_ray, right_ray, top_ray, bottom_ray])

        # RECALCULATE OTHER CAMERAS
        recalculate_cameras()



soft_resize_1s = ->
    app = find_app_root()
    resizing = true
    tick = ->
        if resizing
            requestAnimationFrame(tick)
        render_manager?.resize_soft(app.clientWidth, app.clientHeight)
    requestAnimationFrame(tick)
    end_resize = ->

        resizing = false
        render_manager?.resize(app.clientWidth, app.clientHeight)
    setTimeout(end_resize, 1000)
    main_loop.reset_timeout()



# Remove if there are no transitions affecting the canvas size
window?.addEventListener('resize', soft_resize_1s)



class SnapHelper

    constructor: () ->
        @v = vec3.create()

    set_state_legacy: (state, time, no_easing, visibility_hack) ->
        main_cs = camera_control.camera_states[0]
        current_cs = camera_control.current_camera_state
        if current_cs != main_cs
            set_current_camera_state(main_cs)
        cs = main_cs
        dist = cs.origin_distance = camera_control.last_ray.distance
        v = vec3.set(@v, 0, 0, -dist)
        vec3.transformQuat(v, v, cs.camera.rotation)
        vec3.add(cs.origin_position, v, cs.camera.position)
        quat.copy(cs.origin_rotation, cs.camera.rotation)
        cs.target_distance = state[0]
        vec3.copy(cs.target_position, state[1])
        quat.copy(cs.target_rotation, state[2])
        cs.init_time = performance.now()
        cs.duration = time
        cs.easing = not no_easing
        camera_control.mode = AUTOPILOT
        camera_control.reset_intertia()
        micro = state[4]
        if micro
            # HACK
            vis = visibility_hack?[micro.ob_name]
            if vis and (not vis[4] or vis[7] < 0.2)
                return
            # END HACK
            micro_scene = scenes[micro.scene_name]
            ob = objects[micro.ob_name]
            if ob and micro_scene
                if camera_control.camera_states[1]
                    # TODO: also check if they're not equal
                    destroy_micro_camera_state(camera_control.camera_states[1])
                create_micro_camera_state(micro.point, micro.normal, micro_scene, micro.scale, ob)
                dist = cs.origin_distance = camera_control.last_ray.distance = vec3.dist(cs.origin_position, cs.camera.position)
                vec3.copy(camera_control.last_ray.point, cs.origin_position)

    set_state: (state, time) ->
        if state.length?
            return @set_state_legacy(state, time)

        # We'll add any new scene to camera states
        # then after auto pilot, out of range ones will dissapear
        # by themselves.
        # We treat each state as the same if they have
        # the same scene name and matrix
        # TODO: use matrix to differentiate states
        # and zoom out first

        # We'll use the main camera starting point
        # and the rest of states will be teleported
        # to where the matrices say.
        for s in state.states
            pass

    set_state_callback: (state, time, callback) ->
        @set_state_legacy(state, time, true)
        camera_control.mode = AUTO_BREAKABLE
        camera_control.autopilotCallback = callback

    get_state: () ->
        main_cs = camera_control.camera_states[0]
        current_cs = camera_control.current_camera_state
        if current_cs != main_cs
            set_current_camera_state(main_cs)
        distance = camera_control.last_ray.distance
        rotation = quat.clone(camera_control.current_camera_state.camera.rotation)
        target = vec3.create()
        vec3.set(target, 0, 0, -distance)
        vec3.transformQuat(target, target, rotation)
        vec3.add(target, target, camera_control.current_camera_state.camera.position)
        micro = null
        micro_cs = camera_control.camera_states[1]
        if micro_cs
            micro =
                point: micro_cs.point
                normal: micro_cs.normal
                scale: micro_cs.scale
                ob_name: micro_cs.ob_name
                scene_name: micro_cs.scene_name
        if current_cs != main_cs
            set_current_camera_state(current_cs)
        return [
            distance,
            target,
            rotation,
            scene.name,
            micro,
        ]

    set_state_instant_legacy: (state) ->
        main_cs = camera_control.camera_states[0]
        current_cs = camera_control.current_camera_state
        if current_cs != main_cs
            set_current_camera_state(main_cs)
        cs = main_cs
        v = vec3.set(@v, 0, 0, state[0])
        vec3.transformQuat(v, v, state[2])
        vec3.add(v, v, state[1])
        vec3.copy(scene.active_camera.position, v)
        quat.copy(scene.active_camera.rotation, state[2])
        micro = state[4]
        if micro
            micro_scene = scenes[micro.scene_name]
            ob = objects[micro.ob_name]
            if ob and micro_scene
                if camera_control.camera_states[1]
                    # TODO: also check if they're not equal
                    destroy_micro_camera_state(camera_control.camera_states[1])
                create_micro_camera_state(micro.point, micro.normal, micro_scene, micro.scale, ob)

    set_state_instant: (state) ->
        if state.length?
            return @set_state_instant_legacy(state)




lerp_remainder = (out, src, fac) ->
    # Lerps src to out, and src is assigned the remainder,
    # Note that it mutates src!!
    # out = src * fac
    # src = src * (1-fac)
    vec3.scale(out, src, fac)
    vec3.scale(src, src, 1-fac)
    return out

quat_slerp_remainder = do ->
    zero_q = new Float32Array(4)
    (out, src, fac) ->
        quat.slerp(out, zero_q, src, fac)
        quat.slerp(src, src, zero_q, fac)
        return out
