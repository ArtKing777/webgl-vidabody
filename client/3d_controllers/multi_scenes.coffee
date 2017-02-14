
scene_names = [
    'Scene',
    'empty',
    'heart_cells',
    # 'blood_flow'
    #'neurons',
    #'capi',
    #'ionchan',
    #'ribo',
    #'dna',
]

micro_scene_map =
    'Exterior': 'heart_cells'
    'Circulatory:Heart_wall:Endocardium': 'heart_cells'
    'Muscles:Arm:Brachialis_R_sliced_zone': 'empty'
    # 'blood':'blood_flow'



add_overlay_scene = (name) ->
    scn = get_scene(name)
    shader_lib = SHADER_LIB
    loaded = (scn) ->
        v = new Viewport(scn.active_camera)
        v.set_clear(true, true)
        # Others scripts expects to have "scene" as the main scene
        window.scene = scenes.Scene
        # SHADER_LIB shouldn't be overwritten (TODO: filter in packer instead)
        window.SHADER_LIB = shader_lib if shader_lib
    scn.load_callbacks.append(loaded)
    scn.load()

load_scene = (name, onload) ->
    scn = get_scene(name)
    shader_lib = SHADER_LIB
    loaded = (scn) ->
        if not scn.world and USE_PHYSICS
            scn.on_physics_engine_loaded()
        add_custom_scene_and_mesh_attributes(scn)
        scn.enabled = false
        scn.bg_pass = []
        scn.fg_pass = []
        # Others scripts expects to have "scene" as the main scene
        window.scene = scenes.Scene
        # SHADER_LIB shouldn't be overwritten (TODO: filter in packer instead)
        window.SHADER_LIB = shader_lib if shader_lib
        onload(scn)
    scn.load_callbacks.append(loaded)
    scn.load()


switch_scene = (name) ->
    # NOTE: Not used
    if not scene or not scene.enabled
        return
    scn = scenes[name]
    prev = scene
    scene.enabled = false
    window.scene = scn
    scene.enabled = true
    scene.pre_draw_callbacks = prev.pre_draw_callbacks
    scene.post_draw_callbacks = prev.post_draw_callbacks
    camera_control.current_camera_state.camera = scene.active_camera
    camera_control.camera_states[0].camera = scene.active_camera
    camera_control.camera_states[0].scene = scene

scene_key_switch = (event) ->
    if document.activeElement.tagName=='INPUT' or \
        document.activeElement.isContentEditable
            return
    if event.keyCode >= 49 and event.keyCode < 49+scene_names.length
        switch_scene(scene_names[event.keyCode-49])
# window.addEventListener('keyup', scene_key_switch)


load_micro_scenes = ->

    #add_overlay_scene('widgets')

    for s in scene_names[1...]
        load_scene s, (scn) ->
            scn.micro_scale = 0.00002
            inv_scale = 1/scn.micro_scale
            for ob in scn.lamps
                vec3.scale(ob.position, ob.position, inv_scale)
                ob._update_matrices()
                ob.falloff_distance *= inv_scale
                # There's some mysterious mismatch
                # less noticeale if we do this
                if ob.lamp_type == 'SUN'
                    ob._color4.set([1.7,1.7,1.7,1])


update_micro_scenes = (rays) ->
    # Micro scenes lifetime have several steps that must be
    # performed in this order and undone in opposite order:
    # * Load higher mesh LoD (only physics for now)
    # * Rendervouz (establishing point of encounter, creating camera state)
    # * Swap control (object picking, selection and more precision)

    for ray in rays
        ob = ray?.object
        if ob?.visible
            dist = ray.distance
            micro_scene_name = micro_scene_map[ob.name]
            # if not micro_scene_name
            #     # If there's no micro scene for this object,
            #     # we'll use the empty scene
            #     micro_scene_name = 'empty'

            using_visual_mesh = not ob.physics_mesh or ob._use_visual_mesh
            # Load higher LoD on proximity
            if not glraytest and not using_visual_mesh and dist < 0.02 and ob.alpha > 0.75
                console.log 'instancing higher LoD of '+ob.name
                try
                    ob.instance_physics(true)
                catch
                    console.error 'Error when instancing physics of high LoD of mesh #{ob.name}'
                unselect_all()

            # Rendervouz
            else if dist < 0.005 and not ob.micro_scene_cs
                micro_scene = scenes[micro_scene_name]
                if micro_scene?.loaded
                    console.log 'micro scene rendervouz'
                    cs = create_micro_camera_state(
                        ray.point, ray.normal, micro_scene,
                        micro_scene.micro_scale, ob)

            # # Control swap
            # else if dist < 0.0005 and ob.micro_scene_cs
            #     console.log 'control swap'
            #     set_current_camera_state(ob.micro_scene_cs)

            # Go back to lower LoD when zooming out
            else if ob.physics_mesh and using_visual_mesh and dist > 0.05 and not ob.micro_cloned_original
                console.log 'lowering LoD'
                try
                    ob.instance_physics(false)
                catch
                    console.error 'Error when instancing physics of low LoD of mesh #{ob.name}'

    # TODO: Do this better
    main_camera = camera_control.camera_states[0].camera
    for micro_state in camera_control.camera_states[1...]
        ob = objects[micro_state.ob_name]
        if not ob.visible or ob.alpha < 0.2 or
                vec3.sqrDist(micro_state.point, main_camera.position) > (0.01*0.01)
            destroy_micro_camera_state(micro_state)

    # # Destroy
    # else if dist > 0.01 and ob.micro_scene_cs
    #     console.log 'destroying micro scene'
    #     if ob.micro_scene_cs != camera_control.current_camera_state
    #         destroy_micro_camera_state(ob.micro_scene_cs)
    #         ob.micro_scene_cs = null
    #         try
    #             # TODO: Use same mesh if it's the same mesh
    #             ob.micro_cloned.remove()
    #         catch
    #             console.error 'Error while removing micro clone'
    #
    # # Go back to lower LoD when zooming out
    # else if ob.physics_mesh and ob._use_visual_mesh and dist > 0.05 and not ob.micro_cloned_original
    #     console.log 'lowering LoD'
    #     try
    #         ob.instance_physics(false)
    #     catch
    #         console.error 'Error when instancing physics of low LoD of mesh #{ob.name}'

    # Swap back if Z distance is too high
    cs = camera_control.current_camera_state
    if cs.level > 0 and cs.camera.position[2] > (0.0005/cs.scene.micro_scale)
        console.log 'swap back'
        set_current_camera_state(camera_control.camera_states[0])

    # Destroy
    # for cs in camera_control.camera_states

    # Recalculate existing cameras
    # recalculate_cameras()


recalculate_cameras = (info) ->
    current = camera_control.current_camera_state
    for cs1 in camera_control.camera_states when cs1 != current
        mfrom = cs1.matrix_from_current
        vec3.transformMat4(cs1.camera.position, current.camera.position, cs1.matrix_from_current)
        quat.mul(cs1.camera.rotation, cs1.quat_from_current, current.camera.rotation)
        if info
            console.log "should be",mat4.mul([], mfrom, current.camera.world_matrix)
            console.log "it is", cs1.camera.world_matrix

    #render_manager.debug.vectors.append([
        #camera_control.last_ray.normal,
        #camera_control.last_ray.point,
        #[1,1,1,1]
        #])


create_micro_camera_state = (point, normal, micro_scene, scale, ob) ->
    inv_scale = 1/scale
    cs = new CameraState(micro_scene.active_camera, 1)
    # For restoring state
    cs.point = point
    cs.normal = normal
    cs.scale = scale
    cs.ob_name = ob.name
    cs.scene_name = micro_scene.name
    # The far plane of the micro scene
    # should match the near plane of the parent scene
    # plus a bit of margin to avoid a gap
    cs.camera.far_plane = scene.active_camera.near_plane * inv_scale * 1.01
    # TODO: Make sure the widget overlay scene is always over the rest
    cs.viewport = Viewport(cs.camera)
    # TODO: depth true only when level is different
    cs.viewport.set_clear(false, true)
    micro_scene.enabled = true
    rot = quat.create()
    quat.rotationTo(rot, [0,0,1], normal)
    #quat.copy(rot, scene.active_camera.rotation)
    # gl-matrix quats and ours have opposite signs
    # but in this case the quat comes from gl-matrix
    #rot[3]=-rot[3]
    mat_to = cs.matrix_to_current
    mat_from = cs.matrix_from_current
    mat4.fromRotationTranslation(mat_to, rot, point)
    # gl-matrix's scale function may be wrong, doing the operation in
    # inverse order, but it's what we need
    mat4.scale(mat_to, mat_to, [scale, scale, scale])
    mat4.invert(mat_from, mat_to)
    # ensure imprecision won't move things slightly by inverting them twice
    mat4.invert(mat_to, mat_from)
    mat4.invert(mat_from, mat_to)
    # cache the quat version of the matrix
    quat_from = mat4_to_quat(cs.quat_from_current, mat_from)
    # copy object to micro scene and transform it
    clone = ob.clone(micro_scene)
    # TODO: deal with mirrored object
    # de-mirror, transform, then re-mirror (incl. rotation)
    vec3.transformMat4(clone.position, clone.position, mat_from)
    quat.mul(clone.rotation, quat_from, clone.rotation)
    vec3.scale(clone.scale, clone.scale, inv_scale)
    clone._update_matrices()
    ob.micro_cloned = cs.cloned_object = clone
    clone.micro_cloned_original = ob
    ob.micro_scene_cs = cs
    ob.micro_point = point
    # Set texture LoD values
    clone.custom_uniform_values[3] = scale
    # Rotate lamps
    dest_lamps = micro_scene.lamps[...]
    for lamp in scene.lamps when not lamp.parent
        # Find lamp of same type
        # (assumes one lamp per type,
        # otherwise they may not be in the same order)
        for dest_lamp in dest_lamps when not dest_lamp.parent
            if dest_lamp.lamp_type == lamp.lamp_type
                # if lamp.lamp_type == 'POINT'
                #     vec3.scale(dest_lamp.position, lamp.position, inv_scale)
                quat.mul(dest_lamp.rotation, quat_from, lamp.rotation)
                dest_lamp._update_matrices()
                dest_lamps.remove(dest_lamp)
                break
    # Add itself to camera states
    camera_control.camera_states.append(cs)
    return cs


destroy_micro_camera_state = (cs) ->
    try
        cs.cloned_object.remove()
    catch
        console.error 'Error removing micro clone physics'
    render_manager.viewports.remove(cs.viewport)
    camera_control.camera_states.remove(cs)
    objects[cs.ob_name].micro_scene_cs = null


set_current_camera_state = (current_cs) ->

    camera_control.current_camera_state = current_cs
    matrix_from_old = current_cs.matrix_from_current
    matrix_to_old = current_cs.matrix_to_current

    # to switch, multiply all by the inverse of
    # the new current state
    for cs in camera_control.camera_states
        if cs != current_cs
            mat4.mul(cs.matrix_from_current, matrix_to_old, cs.matrix_from_current)
            mat4.mul(cs.matrix_to_current, matrix_from_old, cs.matrix_to_current)
            mat4_to_quat(cs.quat_from_current, cs.matrix_from_current)
    # Transform orbit, main ray and remove reference to body of old scene
    ray = camera_control.last_ray
    vec3.transformMat4(ray.point, ray.point, matrix_from_old)
    vec3.transformMat4(camera_control.orbit_point, camera_control.orbit_point, matrix_from_old)
    ray.body = null
    # Scale linear camera control variables
    scale = vec3.len(matrix_from_old)
    vec3.scale(camera_control.pan, camera_control.pan, scale)
    vec3.scale(camera_control.ship_move, camera_control.ship_move, scale)
    camera_control.min_distance_smoothed *= scale
    # Reset all transformations of current_cs CameraState
    mat4.identity(matrix_from_old)
    mat4.identity(matrix_to_old)
